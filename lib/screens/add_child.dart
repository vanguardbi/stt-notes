import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stt/screens/children.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({Key? key}) : super(key: key);

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _childNameController = TextEditingController();
  final TextEditingController _parentNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  final List<String> _selectedTracks = [];
  List<String> _availableTracks = [];
  DateTime? _selectedDate;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  @override
  void dispose() {
    _childNameController.dispose();
    _parentNameController.dispose();
    _notesController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _toggleTrack(String track) {
    setState(() {
      if (_selectedTracks.contains(track)) {
        _selectedTracks.remove(track);
      } else {
        _selectedTracks.add(track);
      }
    });
  }

  Future<void> _loadTracks() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('tracks')
          .get();

      setState(() {
        _availableTracks = snapshot.docs.map((doc) {
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

  Future<void> _saveChild() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No user logged in');
      }

      try {
        final docRef = FirebaseFirestore.instance.collection('children').doc();
        await docRef.set({
          'id': docRef.id,
          'childName': _childNameController.text.trim(),
          'parentName': _parentNameController.text.trim(),
          'dateOfBirth': _dobController.text.trim(),
          'tracks': _selectedTracks,
          'notes': _notesController.text.trim(),
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Child added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back
        // Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChildrenListScreen()),
        );
      } catch (e) {
        if (!mounted) return;

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked); // Format date for display
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(title: 'New Child', showBack: true,),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  child: TextFormField(
                    controller: _childNameController,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                    cursorColor: Colors.black,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter child\'s name';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Micah Karuki',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      errorStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
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
                      errorStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
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

                const Text(
                  'Track/s',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._selectedTracks.map((track) => _buildTrackChip(track, true)),
                    ..._availableTracks
                        .where((track) => !_selectedTracks.contains(track))
                        .map((track) => _buildTrackChip(track, false)),
                  ],
                ),
                const SizedBox(height: 20),

                const Text(
                  "Date of Birth",
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
                    controller: _dobController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                    cursorColor: Colors.black,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please select a date of birth';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'YYYY-MM-DD',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      suffixIcon: const Icon(Icons.calendar_today, color: Colors.black54), // Calendar icon
                      errorStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
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

                CustomButton(text: 'Submit', onPressed: _saveChild, isLoading: _isSaving,),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleTrack(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _toggleTrack(label),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}