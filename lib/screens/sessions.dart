import 'package:flutter/material.dart';
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
  final TextEditingController _searchController = TextEditingController();
  Map<String, String> _childrenMap = {};
  bool _isChildrenLoading = true;
  String _searchQuery = '';

  late Stream<List<Map<String, dynamic>>> _sessionsStream;

  @override
  void initState() {
    super.initState();
    _fetchChildren();
    _initSessionsStream();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _fetchChildren() async {
    try {
      final response = await supabase.from('clients').select().order('First Name');
      final Map<String, String> childrenMap = {};
      for (final row in response) {
        final String firstName = row['First Name'] ?? '';
        final String lastName = row['Last Name'] ?? '';
        childrenMap[row['ID']] = '$firstName $lastName'.trim();
      }
      if (mounted) {
        setState(() {
          _childrenMap = childrenMap;
          _isChildrenLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching children: $e');
    }
  }

  void _initSessionsStream() {
    _sessionsStream = supabase
        .from('sessions')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Color _getStatusColor(String status) {

    switch (status) {
      case 'error':
        return Colors.red;
      case 'loading':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(
        title: 'Sessions',
        showBack: true,
      ),
      body: _isChildrenLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14),
                cursorColor: Colors.black,
                decoration: InputDecoration(
                  hintText: 'Search by client name...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                    onPressed: () => _searchController.clear(),
                  )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _sessionsStream,
              builder: (context, snapshot) {
                // 1. Check for errors
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                // 2. Check for loading state
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 3. Filter the stream data locally based on search query
                final allSessions = snapshot.data!;
                final filteredSessions = allSessions.where((session) {
                  final childId = session['child_id'] ?? '';
                  final childName = _childrenMap[childId] ?? 'Unknown';
                  return childName.toLowerCase().contains(_searchQuery);
                }).toList();

                // 4. Handle Empty State
                if (filteredSessions.isEmpty) {
                  return _buildEmptyState();
                }

                // 5. Build the List
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSessions.length,
                  itemBuilder: (context, index) {
                    final sessionData = filteredSessions[index];
                    final String childId = sessionData['child_id'] ?? '';
                    final bool isError = sessionData['generating_report_error'] ?? false;
                    final bool isLoadingReport = sessionData['generating_report'] ?? false;
                    final String? audioUrl = sessionData['audio_url'];
                    final List? tracks = sessionData['tracks'];

                    String status = 'initial';

                    if (isError) {
                      status = 'error';
                    } else if (isLoadingReport) {
                      status = 'loading';
                    } else if (audioUrl != null && audioUrl.isNotEmpty) {
                      status = 'completed';
                    } else if (tracks != null && tracks.isNotEmpty) {
                      status = 'pending';
                    } else {
                      status = 'initial';
                    }

                    final childName = _childrenMap[childId] ?? 'Unknown';
                    final DateTime createdAt = DateTime.parse(sessionData['created_at']);
                    final dateStr = '${createdAt.day}/${createdAt.month}/${createdAt.year}';

                    return _buildSessionCard(sessionData, childName, dateStr, status);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> sessionData, String childName, String dateStr, String status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF00C4B3),
                child: const Icon(Icons.mic, color: Colors.black87, size: 20),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  height: 12,
                  width: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            childName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
          trailing: Text(
            dateStr,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SessionDetailsScreen(sessionId: sessionData['id']),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_searchQuery.isEmpty ? Icons.mic_none : Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(_searchQuery.isEmpty ? 'No sessions yet' : 'No sessions found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }
}