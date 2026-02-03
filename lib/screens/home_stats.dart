import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stt/screens/session_details.dart';
import 'package:stt/screens/sessions.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';

class HomeStats extends StatefulWidget {
  const HomeStats({Key? key}) : super(key: key);

  @override
  State<HomeStats> createState() => _HomeStatsState();
}

class _HomeStatsState extends State<HomeStats> {
  final supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _fetchRecentSessions();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _sessionsFuture = _fetchRecentSessions();
    });
    await _sessionsFuture;
  }

  // Fetch last 5 sessions
  Future<List<Map<String, dynamic>>> _fetchRecentSessions() async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from('sessions')
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false)
        .limit(5);

    return response;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getUserName() {
    final user = supabase.auth.currentUser;
    final name = user?.userMetadata?['full_name'];
    if (name != null) {
      return name.split(' ').first;
    }
    return "User";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(title: '${_getGreeting()}, ${_getUserName()}'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 32.0, left: 16.0, right: 16.0),
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
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _sessionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final sessions = snapshot.data ?? [];

                if (sessions.isEmpty) {
                  // Wrapped empty state in RefreshIndicator + Scrollable view
                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mic_none, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No sessions yet',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                              const SizedBox(height: 8),
                              Text('Start by recording a session',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: const Color(0xFF00C4B3),
                  child: ListView.builder(
                    // physics ensures drag works even if the list is short
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final childName = session['child_name'] ?? '';
                      final createdAt = DateTime.parse(session['created_at']);
                      final dateStr = "${createdAt.day}/${createdAt.month}/${createdAt.year}";

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SessionDetailsScreen(
                                    sessionId: session['id'],
                                  ),
                                ),
                              );
                              _handleRefresh();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          // See All Sessions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'See All Sessions',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SessionsScreen()),
                  );
                  _handleRefresh(); // Refresh when coming back
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
