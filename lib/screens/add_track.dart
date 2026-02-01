import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stt/utils/utils.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddTrackScreen extends StatefulWidget {
  final List<String> existingTracks;
  final TrackWithObjectives? initialTrack;

  const AddTrackScreen({
    Key? key,
    required this.existingTracks,
    this.initialTrack,
  }) : super(key: key);

  @override
  State<AddTrackScreen> createState() => _AddTrackScreenState();
}

class _AddTrackScreenState extends State<AddTrackScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _objectiveControllers = [];

  String? _selectedTrack;
  List<String> _tracks = [];
  bool _isLoadingTracks = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();

    if (widget.initialTrack != null) {
      _selectedTrack = widget.initialTrack!.trackName;
      // Add controllers for existing objectives
      for (var objective in widget.initialTrack!.objectives) {
        final controller = TextEditingController(text: objective);
        _objectiveControllers.add(controller);
      }
    } else {
      // Start with one empty objective field
      _objectiveControllers.add(TextEditingController());
    }
  }

  Future<void> _loadTracks() async {
    try {
      final response = await supabase
          .from('tracks')
          .select('name')
          .order('name');

      final allTracks =
      response.map<String>((e) => e['name'] as String).toList();

      setState(() {
        _tracks = allTracks.where((track) {
          if (widget.initialTrack != null &&
              track == widget.initialTrack!.trackName) {
            return true;
          }
          return !widget.existingTracks.contains(track);
        }).toList();

        _isLoadingTracks = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTracks = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tracks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addObjectiveField() {
    setState(() {
      _objectiveControllers.add(TextEditingController());
    });
  }

  void _removeObjectiveField(int index) {
    if (_objectiveControllers.length > 1) {
      setState(() {
        _objectiveControllers[index].dispose();
        _objectiveControllers.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one objective is required'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _saveTrack() {
    if (_formKey.currentState!.validate()) {
      if (_selectedTrack == null || _selectedTrack!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a track'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final objectives = _objectiveControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (objectives.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one objective'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final trackWithObjectives = TrackWithObjectives(
        trackName: _selectedTrack!,
        objectives: objectives,
      );

      Navigator.pop(context, trackWithObjectives);
    }
  }

  @override
  void dispose() {
    for (var controller in _objectiveControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(
        title: widget.initialTrack != null ? 'Edit Track' : 'Add Track',
        showBack: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isLoadingTracks
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
                    onChanged: widget.initialTrack != null
                        ? null
                        : (value) {
                      setState(() {
                        _selectedTrack = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Objectives',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _objectiveControllers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: _objectiveControllers[index],
                              style: const TextStyle(fontSize: 14),
                              cursorColor: Colors.black,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Enter objective ${index + 1}',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                        ),
                        // Only show delete button if more than one objective
                        if (_objectiveControllers.length > 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            child: IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () => _removeObjectiveField(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addObjectiveField,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Objective'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Theme.of(context).primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                CustomButton(
                  text: widget.initialTrack != null ? 'Update Track' : 'Add Track',
                  onPressed: _saveTrack,
                  isLoading: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}