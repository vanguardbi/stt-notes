import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stt/screens/recording.dart';

class AddSessionScreen extends StatefulWidget {
  const AddSessionScreen({Key? key}) : super(key: key);

  @override
  State<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _parentNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedChildId;
  String? _selectedChildName;
  String? _selectedTrack;
  List<Map<String, dynamic>> _children = [];
  bool _isLoadingChildren = true;
  bool _isSaving = false;

  final List<String> _tracks = ['Late Talking', 'Stuttering'];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('children')
          .orderBy('childName')
          .get();

      setState(() {
        _children = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc.data() != null ? (doc.data() as Map<String, dynamic>)['childName'] ?? 'Unknown' : 'Unknown',
          };
        }).toList();
        _isLoadingChildren = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingChildren = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading children: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startSession() async {
    if (_formKey.currentState!.validate()) {
      // Navigate to recording screen with session details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecordingSessionScreen(
            childId: _selectedChildId!,
            childName: _selectedChildName!,
            parentName: _parentNameController.text.trim(),
            track: _selectedTrack!,
            notes: _notesController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _parentNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE0E0E0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Session',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Child's Name Dropdown
                const Text(
                  "Child's Name",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isLoadingChildren
                      ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                      : DropdownButtonFormField<String>(
                    value: _selectedChildId,
                    decoration: InputDecoration(
                      hintText: 'Micah Karuki',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a child';
                      }
                      return null;
                    },
                    items: _children.map((child) {
                      return DropdownMenuItem<String>(
                        value: child['id'],
                        child: Text(
                          child['name'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedChildId = value;
                        _selectedChildName = _children.firstWhere(
                              (child) => child['id'] == value,
                        )['name'];
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Parent's Name
                const Text(
                  "Parent's Name",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    controller: _parentNameController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter parent\'s name';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'George Osieko',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Track Dropdown
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedTrack,
                    decoration: InputDecoration(
                      hintText: 'Late Talking',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a track';
                      }
                      return null;
                    },
                    items: _tracks.map((track) {
                      return DropdownMenuItem<String>(
                        value: track,
                        child: Text(
                          track,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTrack = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Notes
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _notesController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save All Recordings Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _startSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD0D0D0),
                      foregroundColor: Colors.black87,
                      disabledBackgroundColor: const Color(0xFFE8E8E8),
                      disabledForegroundColor: Colors.black38,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                      ),
                    )
                        : const Text(
                      'Start Session',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}