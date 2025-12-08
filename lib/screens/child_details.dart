import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stt/screens/session_details.dart';
import 'package:stt/screens/sessions.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';

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
  String selectedTrack = 'All Tracks';
  List<String> tracks = [];

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('tracks')
          .get();

      setState(() {
        tracks = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          return data?['name'] ?? 'Unknown';
        }).cast<String>().toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tracks: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Stream<QuerySnapshot> _getSessionsStream() {
    return FirebaseFirestore.instance
        .collection('sessions')
        .where('childId', isEqualTo: widget.childId)
        .orderBy('createdAt', descending: true)
        .snapshots();
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

    return sessionData['track'] ?? 'Unknown Track';
  }

  String _getTrackInitial(Map<String, dynamic> sessionData) {
    final trackName = _getDisplayTrackName(sessionData);
    final firstChar = trackName.trim().isNotEmpty ? trackName.trim()[0] : 'S';
    return firstChar.toUpperCase();
  }

  List<QueryDocumentSnapshot> _filterSessions(List<QueryDocumentSnapshot> allSessions) {
    if (selectedTrack == 'All Tracks') {
      return allSessions;
    }

    return allSessions.where((sessionDoc) {
      final sessionData = sessionDoc.data() as Map<String, dynamic>;

      final oldTrack = sessionData['track'] as String?;
      if (oldTrack != null && oldTrack == selectedTrack) {
        return true;
      }

      final newTracks = sessionData['tracks'] as List<dynamic>?;
      if (newTracks != null) {
        return newTracks.any((trackData) {
          if (trackData is Map<String, dynamic>) {
            return trackData['trackName'] == selectedTrack;
          }
          return false;
        });
      }

      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                  child: DropdownButton<String>(
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

          // Sessions List (StreamBuilder now uses _getSessionsStream and filters data)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getSessionsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                    ),
                  );
                }

                final filteredDocs = _filterSessions(snapshot.data!.docs);

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          selectedTrack != 'All Tracks'
                              ? 'No sessions for $selectedTrack'
                              : 'No sessions yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var sessionDoc = filteredDocs[index];
                    var sessionData = sessionDoc.data() as Map<String, dynamic>;

                    String displayTrack = _getDisplayTrackName(sessionData);
                    String trackInitial = _getTrackInitial(sessionData);

                    Timestamp? timestamp = sessionData['createdAt'];
                    String dateStr = timestamp != null
                        ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
                        : '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF00C4B3),
                            child: Text(
                              trackInitial,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          title: Text(
                            displayTrack,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          trailing: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          onTap: () {
                            // Navigate to session details
                            print('Tapped on session: $displayTrack');
                            Navigator.push(context, MaterialPageRoute(builder: (context) => SessionDetailsScreen(sessionId: sessionDoc.id,), ),);
                          },
                        ),
                      ),
                    );
                  },
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