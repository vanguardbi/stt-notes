import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stt/screens/recording.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';

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
  List<String> _tracks = [];

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _loadTracks();
  }

  Future<void> _loadChildren() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('children')
          .orderBy('childName')
          .get();

      setState(() {
        _children = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return {
            'id': doc.id,
            'name': data['childName'] ?? '',
            'parentName': data['parentName'] ?? '',
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

  Future<void> _loadTracks() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('tracks')
          .get();

      setState(() {
        _tracks = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          return data?['name'] ?? 'Unknown';
        }).cast<String>().toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tracks: $e'), backgroundColor: Colors.red),
      );
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(title: 'New Session', showBack: true,),
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
                    hint: Text(
                      'Select a child',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    decoration: InputDecoration(
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
                      isDense: true,
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
                        final selectedChild = _children.firstWhere((child) => child['id'] == value);
                        _selectedChildName = selectedChild['name'];
                        _parentNameController.text = selectedChild['parentName'] ?? '';
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
                    readOnly: true,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                    cursorColor: Colors.black,
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
                    hint: Text(
                      'Select track',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    decoration: InputDecoration(
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
                      isDense: true,
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
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                    cursorColor: Colors.black,
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

                // Save Session Button
                CustomButton(text: 'Start Session', onPressed: _startSession, isLoading: _isSaving,),
              ],
            ),
          ),
        ),
      ),
    );
  }
}