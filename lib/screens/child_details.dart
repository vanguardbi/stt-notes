import 'package:flutter/material.dart';
import 'package:stt/screens/session_details.dart';
import 'package:stt/screens/sessions.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChildDetailsScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const ChildDetailsScreen({
    Key? key,
    required this.childId,
    required this.childName,
  }) : super(key: key);

  @override
  State<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends State<ChildDetailsScreen> {
  final supabase = Supabase.instance.client;
  String selectedTrack = 'All Tracks';
  List<String> tracks = [];

  bool isLoadingTracks = true;
  bool isLoadingSessions = true;

  List<Map<String, dynamic>> sessions = [];

  @override
  void initState() {
    super.initState();
    _loadTracks();
    _loadSessions();
  }

  Future<void> _loadTracks() async {
    try {
      final response = await supabase.from('tracks').select('name').order('name');

      setState(() {
        tracks = response.map<String>((e) => e['name'] as String).toList();
        isLoadingTracks = false;
      });
    } catch (e) {
      isLoadingTracks = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tracks: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadSessions() async {
    try {
      final response = await supabase
          .from('sessions')
          .select('id, created_at, tracks')
          .eq('child_id', widget.childId)
          .order('created_at', ascending: false);

      setState(() {
        sessions = List<Map<String, dynamic>>.from(response);
        isLoadingSessions = false;
      });
    } catch (e) {
      isLoadingSessions = false;
      _showError('Error loading sessions: $e');
    }
  }

  String _getDisplayTrackName(Map<String, dynamic> sessionData) {
    final newTracks = sessionData['tracks'] as List<dynamic>?;
    if (newTracks != null && newTracks.isNotEmpty) {
      final trackNames = newTracks.map((trackData) {
        if (trackData is Map<String, dynamic>) {
          return trackData['trackName'] as String?;
        }
        return null;
      }).where((name) => name != null).toList();

      if (trackNames.isNotEmpty) {
        return trackNames.join(', ');
      }
    }

    return sessionData['track'] ?? 'Unspecified Track';
  }

  String _getTrackInitial(Map<String, dynamic> sessionData) {
    final trackName = _getDisplayTrackName(sessionData);
    final firstChar = trackName.trim().isNotEmpty ? trackName.trim()[0] : 'S';
    return firstChar.toUpperCase();
  }

  List<Map<String, dynamic>> _filteredSessions() {
    if (selectedTrack == 'All Tracks') {
      return sessions;
    }

    return sessions.where((session) {
      final tracksData = session['tracks'] as List<dynamic>?;

      if (tracksData == null) return false;

      return tracksData.any((track) =>
      track is Map &&
          track['trackName'] == selectedTrack);
    }).toList();
  }

  String _displayTrackName(Map<String, dynamic> session) {
    final tracksData = session['tracks'] as List<dynamic>?;

    if (tracksData != null && tracksData.isNotEmpty) {
      return tracksData
          .map((e) => e['trackName'])
          .whereType<String>()
          .join(', ');
    }

    return 'Unspecified Track';
  }

  String _trackInitial(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : 'S';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSessions = _filteredSessions();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(title: widget.childName, showBack: true,),
      body: Column(
        children: [
          // Track Dropdown Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Track',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isLoadingTracks
                      ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : DropdownButton<String>(
                    isExpanded: true,
                    value: selectedTrack,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'All Tracks',
                        child: Row(
                          children: [
                            Icon(Icons.filter_list, size: 16, color: Colors.black54),
                            SizedBox(width: 8),
                            Text(
                              'All Tracks',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...tracks.map((String track) {
                        return DropdownMenuItem<String>(
                          value: track,
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              Text(
                                track,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedTrack = newValue ?? 'All Tracks';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoadingSessions
                ? const Center(child: CircularProgressIndicator())
                : filteredSessions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    selectedTrack == 'All Tracks'
                        ? 'No sessions yet'
                        : 'No sessions for $selectedTrack',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredSessions.length,
              itemBuilder: (context, index) {
                final session = filteredSessions[index];
                final trackName = _displayTrackName(session);
                final createdAt =
                DateTime.parse(session['created_at']);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                        const Color(0xFF00C4B3),
                        child: Text(
                          _trackInitial(trackName),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      title: Text(trackName),
                      trailing: Text(
                        '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600]),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SessionDetailsScreen(
                              sessionId: session['id'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: CustomButton(
                  text: 'See All Sessions',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SessionsScreen()));
                  }
              ),
            ),
          ),
        ],
      ),
    );
  }
}