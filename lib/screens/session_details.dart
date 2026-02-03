import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:stt/screens/add_track.dart';
import 'package:stt/screens/recording.dart';
import 'package:stt/utils/utils.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SessionDetailsScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailsScreen({
    Key? key,
    required this.sessionId,
  }) : super(key: key);

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  final _supabase = Supabase.instance.client;
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;

  Map<String, dynamic>? _sessionData;
  String? _childName;
  String? _childId;
  String _sessionId = "";
  bool _isLoading = true;
  bool _isSaving = false;
  List<TrackWithObjectives> _selectedTracks = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _fetchSessionData();
  }

  Future<void> _initPlayer() async {
    try {
      await _audioPlayer.openPlayer();
      setState(() {
        _isPlayerInitialized = true;
      });
    } catch (e) {
      print('Error initializing player: $e');
    }
  }

  void _navigateToAddTrack() async {
    final result = await Navigator.push<TrackWithObjectives>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTrackScreen(
          existingTracks: _selectedTracks.map((t) => t.trackName).toList(),
        ),
      ),
    );

    if (result != null) {
      setState(() => _selectedTracks.add(result));
    }
  }

  void _editTrack(int index) async {
    final track = _selectedTracks[index];
    final result = await Navigator.push<TrackWithObjectives>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTrackScreen(
          existingTracks: _selectedTracks
              .asMap()
              .entries
              .where((entry) => entry.key != index)
              .map((entry) => entry.value.trackName)
              .toList(),
          initialTrack: track,
        ),
      ),
    );

    if (result != null) {
      setState(() => _selectedTracks[index] = result);
    }
  }

  void _removeTrack(int index) {
    setState(() => _selectedTracks.removeAt(index));
  }

  // void _startSession() async {
  //   final tracksData = _selectedTracks.map((track) => track.toMap()).toList();
  //
  //   await _supabase.from('sessions').update({
  //     'tracks': tracksData,
  //   }).eq('id', _sessionId);
  //
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => RecordingSessionScreen(
  //         childId: _childId!,
  //         childName: _childName!,
  //         sessionId: _sessionId,
  //         tracks: _selectedTracks,
  //       ),
  //     ),
  //   );
  // }

  Future<void> _updateTracksInDb() async {
    setState(() => _isSaving = true);
    try {
      final tracksData = _selectedTracks.map((track) => track.toMap()).toList();
      await _supabase.from('sessions').update({
        'tracks': tracksData,
      }).eq('id', _sessionId);
      print('_sessionId $_sessionId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving session'), backgroundColor: Colors.red),
        );
      }
      rethrow; // Pass error up so navigation doesn't happen on failure
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

// Handler for "Save Session" button
  void _handleSaveOnly() async {
    try {
      await _updateTracksInDb();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session details updated'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
  }

  // Handler for "Start Recording" button
  void _handleStartRecording() async {
    try {
      await _updateTracksInDb();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecordingSessionScreen(
              childId: _childId!,
              childName: _childName!,
              sessionId: _sessionId,
              tracks: _selectedTracks,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchSessionData() async {
    try {
      final sessionData = await _supabase
          .from('sessions')
          .select()
          .eq('id', widget.sessionId)
          .single();

      String childName = '';
      final String? childId = sessionData['child_id'];
      String sessionDataId =  sessionData['id'];

      if (childId != null && childId.isNotEmpty) {
        final childData = await _supabase
            .from('clients')
            .select()
            .eq('ID', childId)
            .single();

        final String firstName = childData['First Name'] ?? '';
        final String lastName = childData['Last Name'] ?? '';
        childName = '$firstName $lastName'.trim() ?? 'Unknown Client';
      }
      List<TrackWithObjectives> existingTracks = [];
      if (sessionData['tracks'] != null && sessionData['tracks'] is List) {
        existingTracks = (sessionData['tracks'] as List).map((trackMap) {
          return TrackWithObjectives(
            trackName: trackMap['trackName'] ?? '',
            objectives: List<String>.from(trackMap['objectives'] ?? []),
          );
        }).toList();
      }

      setState(() {
        _sessionData = sessionData;
        _sessionId = sessionDataId;
        _childName = childName;
        _childId = childId;
        _selectedTracks = existingTracks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching session: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _playAudio() async {
    if (_sessionData == null || !_isPlayerInitialized) return;

    String? audioUrl = _sessionData!['audio_url'];
    if (audioUrl == null || audioUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio recording available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.stopPlayer();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioPlayer.startPlayer(
          fromURI: audioUrl,
          whenFinished: () {
            setState(() {
              _isPlaying = false;
            });
          },
        );
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openTranscriptUrl() async {
    if (_sessionData!['doc_url'] == null || _sessionData!['doc_url']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcript URL not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final Uri url = Uri.parse(_sessionData!['doc_url']!);
      // if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      // } else {
      //   throw Exception('Could not launch URL');
      // }
    } catch (e) {
      print('Error opening transcript URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening transcript: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.closePlayer();
    super.dispose();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    DateTime date = DateTime.parse(dateString).toLocal();
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '0:00';
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildAddSessionForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TextLabel(labelName: 'Client Name'),
              const SizedBox(height: 8),
              InputBoxContainer(inputText: _childName ?? ""),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TextLabel(labelName: 'Tracks'),
                  TextButton.icon(
                    onPressed: _navigateToAddTrack,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Track'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_selectedTracks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No tracks added yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedTracks.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final track = _selectedTracks[index];
                    return Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    track.trackName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _editTrack(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  onPressed: () => _removeTrack(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                          if (track.objectives.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Objectives:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...track.objectives.asMap().entries.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '${entry.key + 1}. ${entry.value}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Save Session',
                onPressed: _isSaving ? null : _handleSaveOnly,
                isLoading: _isSaving
              ),

              const SizedBox(height: 24),

              CustomButton(
                text: 'Start Recording',
                onPressed: _isSaving ? null : _handleStartRecording,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionDetails() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _childName ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const TextLabel(labelName: 'Client Name'),
            const SizedBox(height: 8),
            InputBoxContainer(inputText: _childName ?? ""),
            const SizedBox(height: 20),

            const TextLabel(labelName: 'Tracks & Objectives'),
            const SizedBox(height: 8),

            if (_sessionData!['tracks'] is List && (_sessionData!['tracks'] as List).isNotEmpty)
              ...(_sessionData!['tracks'] as List).map((trackData) {
                if (trackData is Map<String, dynamic>) {
                  final String trackName = trackData['trackName'] ?? '';
                  final List<dynamic> objectives = trackData['objectives'] is List ? trackData['objectives'] as List : [];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InputBoxContainer(inputText: 'Track: $trackName', color: const Color(0xFFE0E0E0)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: objectives.isEmpty
                              ? const Text('No objectives for this track.', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic))
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: objectives.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final String objective = entry.value.toString();
                              return Padding(
                                padding: EdgeInsets.only(top: index == 0 ? 0 : 8.0),
                                child: Text(
                                  '• $objective',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }).toList()
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('No tracks and objectives recorded.', style: TextStyle(fontSize: 14)),
              ),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatDate(_sessionData!['created_at']),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Duration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _sessionData!['duration'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _playAudio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPlaying ? const Color(0xFFFF5959) : const Color(0xFF00C4B3),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _isPlaying ? 'Stop Recording' : 'Listen to Recording',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Transcript', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _sessionData!['formatted_conversation']?.isEmpty ?? true
                    ? 'No transcript available'
                    : _sessionData!['formatted_conversation'],
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Outcomes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _sessionData!['outcomes']?.isEmpty ?? true
                    ? 'No outcomes recorded'
                    : _sessionData!['outcomes'],
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Plans for Next Session', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _sessionData!['next_session_plans']?.isEmpty ?? true
                    ? 'No plans recorded'
                    : _sessionData!['next_session_plans'],
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'View Summary in Google Docs',
                onPressed: _sessionData!['doc_url'] != null && _sessionData!['doc_url']!.isNotEmpty
                    ? _openTranscriptUrl
                    : null,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAudioUrl = _sessionData != null && _sessionData!['audio_url'] != null && _sessionData!['audio_url']!.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(title: 'Session Details', showBack: true,),
      body: _isLoading ?
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
          ),
        ): _sessionData == null
            ? const Center(
          child: Text(
            'Session not found',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        ) :
        hasAudioUrl ? _buildSessionDetails() : _buildAddSessionForm(),
    );
  }
}
