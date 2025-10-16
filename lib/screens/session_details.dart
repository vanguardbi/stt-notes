import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';

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
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;

  Map<String, dynamic>? _sessionData;
  String? _childName;
  bool _isLoading = true;

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

  Future<void> _fetchSessionData() async {
    try {
      // Fetch session data
      DocumentSnapshot sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      Map<String, dynamic> sessionData = sessionDoc.data() as Map<String, dynamic>;

      // Fetch child name using childId
      String childId = sessionData['childId'] ?? '';
      String childName = 'Unknown Child';

      if (childId.isNotEmpty) {
        DocumentSnapshot childDoc = await FirebaseFirestore.instance
            .collection('children')
            .doc(childId)
            .get();

        if (childDoc.exists) {
          Map<String, dynamic> childData = childDoc.data() as Map<String, dynamic>;
          childName = childData['childName'] ?? 'Unknown Child';
        }
      }

      setState(() {
        _sessionData = sessionData;
        _childName = childName;
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

    String? audioUrl = _sessionData!['audioUrl'];
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

  @override
  void dispose() {
    _audioPlayer.closePlayer();
    super.dispose();
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '0:00';
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF5959),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Session Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
        ),
      )
          : _sessionData == null
          ? const Center(
        child: Text(
          'Session not found',
          style: TextStyle(fontSize: 16, color: Colors.red),
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child Name Header
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
                      _childName ?? 'Unknown Child',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Child Name
              const Text('Child Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_childName ?? 'Unknown Child', style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 20),

              // Parent's Name
              const Text("Parent's Name", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _sessionData!['parentName'] ?? 'N/A',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Track
              const Text('Track', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _sessionData!['track'] ?? 'N/A',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Session Date and Duration
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
                            _formatDate(_sessionData!['createdAt']),
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
                            _formatDuration(_sessionData!['duration']),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Listen to Recording Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _playAudio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPlaying ? const Color(0xFFFF5959) : const Color(0xFFD0D0D0),
                    foregroundColor: Colors.black87,
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

              // Notes
              const Text('Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _sessionData!['notes']?.isEmpty ?? true
                      ? 'No notes'
                      : _sessionData!['notes'],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Transcript
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
                  _sessionData!['transcript']?.isEmpty ?? true
                      ? 'No transcript available'
                      : _sessionData!['transcript'],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Summary (Placeholder for future AI summary)
              const Text('Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(minHeight: 100),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'AI-generated summary will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}