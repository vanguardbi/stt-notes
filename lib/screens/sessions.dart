import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stt/screens/session_details.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({Key? key}) : super(key: key);

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final supabase = Supabase.instance.client;

  String _selectedChildId = 'all';
  String _selectedChildName = 'All Clients';
  Map<String, String> _childrenMap = {};
  bool _isLoadingChildren = true;

  @override
  void initState() {
    super.initState();
    _fetchChildren();
  }

  Future<void> _fetchChildren() async {
    try {
      // QuerySnapshot childrenSnapshot = await FirebaseFirestore.instance
      //     .collection('children')
      //     .get();
      final response = await supabase.from('clients').select().order('First Name');

      Map<String, String> childrenMap = {};
      for (final row in response) {
        final String firstName = row['First Name'] ?? '';
        final String lastName = row['Last Name'] ?? '';

        childrenMap[row['ID']] = '$firstName $lastName'.trim();
      }
      // for (var doc in childrenSnapshot.docs) {
      //   var data = doc.data() as Map<String, dynamic>;
      //   String childId = doc.id;
      //   String childName = data['childName'] ?? 'Unknown Client';
      //   childrenMap[childId] = childName;
      // }

      setState(() {
        _childrenMap = childrenMap;
        _isLoadingChildren = false;
      });
    } catch (e) {
      print('Error fetching children: $e');
      setState(() {
        _isLoadingChildren = false;
      });
    }
  }

  // Stream<QuerySnapshot> _getSessionsStream() {
  //   if (_selectedChildId == 'all') {
  //     return FirebaseFirestore.instance
  //         .collection('sessions')
  //         .orderBy('createdAt', descending: true)
  //         .snapshots();
  //   } else {
  //     return FirebaseFirestore.instance
  //         .collection('sessions')
  //         .where('childId', isEqualTo: _selectedChildId)
  //         .orderBy('createdAt', descending: true)
  //         .snapshots();
  //   }
  // }
  Future<List<Map<String, dynamic>>> _fetchSessions() async {
    if (_selectedChildId == 'all') {
      return await supabase
          .from('sessions')
          .select('id, child_id, created_at')
          .order('created_at', ascending: false);
    }

    return await supabase
        .from('sessions')
        .select('id, child_id, created_at')
        .eq('child_id', _selectedChildId)
        .order('created_at', ascending: false);
  }

  String _getChildNameById(String childId) {
    return _childrenMap[childId] ?? 'Unknown Client';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(title: 'Sessions', showBack: true,),
      body: Column(
        children: [
          // Dropdown Filter
          Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _isLoadingChildren
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                    ),
                  ),
                ),
              )
                  : DropdownButton<String>(
                value: _selectedChildId,
                isExpanded: true,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: 'all',
                    child: Text('All Clients'),
                  ),
                  ..._childrenMap.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedChildId = newValue;
                      _selectedChildName = newValue == 'all'
                          ? 'All Clients'
                          : _childrenMap[newValue] ?? 'Unknown Client';
                    });
                  }
                },
              ),
            ),
          ),

          // Sessions List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchSessions(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading sessions',
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

                final sessions = snapshot.data ?? [];
                if (sessions.isEmpty) {
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
                          _selectedChildId == 'all'
                              ? 'No sessions yet'
                              : 'No sessions for $_selectedChildName',
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
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final sessionData = sessions[index];
                    String childId = sessionData['child_id'] ?? '';
                    final childName = _childrenMap[childId] ?? 'Unknown Client';
                    // Timestamp? timestamp = sessionData['created_at'];

                    final DateTime createdAt = DateTime.parse(sessionData['created_at']);
                    final dateStr = '${createdAt.day}/${createdAt.month}/${createdAt.year}';

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
                            child: const Icon(
                              Icons.mic,
                              color: Colors.black87,
                              size: 20,
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
                            Navigator.push(context, MaterialPageRoute(builder: (context) => SessionDetailsScreen(sessionId: sessionData['id'],), ),);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}