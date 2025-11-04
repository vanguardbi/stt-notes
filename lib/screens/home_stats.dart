import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stt/screens/add_session.dart';
import 'package:stt/screens/session_details.dart';
import 'package:stt/screens/sessions.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';

class HomeStats extends StatelessWidget {
  const HomeStats({Key? key}) : super(key: key);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  String _getUserName() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null) {
      return user.displayName!.split(' ').first; // Get first name
    }
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(title: '${_getGreeting()}, ${_getUserName()}'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Record a Session Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
            child: CustomButton(
              text: 'Record a Session',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddSessionScreen()));
              }
            ),
          ),

          const SizedBox(height: 12),

          // Recent Sessions Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Recent Sessions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Last 5 Sessions List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_none,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No sessions yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start by recording a session',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var sessionData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    String childName = sessionData['childName'] ?? '';
                    Timestamp? timestamp = sessionData['createdAt'];
                    String dateStr = '';

                    if (timestamp != null) {
                      DateTime date = timestamp.toDate();
                      dateStr = '${date.day}/${date.month}/${date.year}';
                    }

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
                              childName.isNotEmpty ? childName[0].toUpperCase() : 'C',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          title: Text(
                            childName,
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
                            print('Tapped on session: $childName');
                            Navigator.push(context, MaterialPageRoute(builder: (context) => SessionDetailsScreen(sessionId: snapshot.data!.docs[index].id,), ),);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // See All Sessions Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'See All Sessions',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SessionsScreen()));
                }
                )
            ),
          ),
        ],
      ),
    );
  }
}