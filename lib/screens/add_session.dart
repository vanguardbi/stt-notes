import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stt/screens/add_track.dart';
import 'package:stt/screens/recording.dart';
import 'package:stt/utils/utils.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddSessionScreen extends StatefulWidget {
  const AddSessionScreen({Key? key}) : super(key: key);

  @override
  State<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _parentNameController = TextEditingController();

  final supabase = Supabase.instance.client;

  String? _selectedChildId;
  String? _selectedChildName;
  List<Map<String, dynamic>> _children = [];
  bool _isLoadingChildren = true;
  bool _isSaving = false;
  List<TrackWithObjectives> _selectedTracks = [];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      final response = await supabase
          .from('clients')
          .select()
          .order('child_name');

      setState(() {
        _children = response.map<Map<String, dynamic>>((row) {
          final String firstName = row['First Name'] ?? '';
          final String lastName = row['Last Name'] ?? '';

          return {
            'id': row['ID'].toString(),
            // 'name': row['child_name'] ?? '',
            'name': '$firstName $lastName'.trim(),
            // 'parentName': row['parent_name'] ?? '',
            // 'parentName': '$firstName $lastName'.trim(),
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

  void _navigateToAddTrack() async {
    final result = await Navigator.push<TrackWithObjectives>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTrackScreen(
          existingTracks: _selectedTracks.map((t) => t.trackName).toList(),
        ),
      ),
    );

    if (result != null) {
      setState(() => _selectedTracks.add(result));
    }
  }

  void _editTrack(int index) async {
    final track = _selectedTracks[index];
    final result = await Navigator.push<TrackWithObjectives>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTrackScreen(
          existingTracks: _selectedTracks
              .asMap()
              .entries
              .where((entry) => entry.key != index)
              .map((entry) => entry.value.trackName)
              .toList(),
          initialTrack: track,
        ),
      ),
    );

    if (result != null) {
      setState(() => _selectedTracks[index] = result);
    }
  }

  void _removeTrack(int index) {
    setState(() => _selectedTracks.removeAt(index));
  }

  void _startSession() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedTracks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one track'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => RecordingSessionScreen(
      //       childId: _selectedChildId!,
      //       childName: _selectedChildName!,
      //       // parentName: _parentNameController.text.trim(),
      //       tracks: _selectedTracks,
      //     ),
      //   ),
      // );
    }
  }

  @override
  void dispose() {
    _parentNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(
        title: 'New Session',
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
                // Child's Name Dropdown
                const Text(
                  "Client's Name",
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
                      : DropdownSearch<String>(
                    items: (filter, infiniteScrollProps) =>
                        _children.map((child) => child['id'] as String).toList(),
                    selectedItem: _selectedChildId,
                    decoratorProps: DropDownDecoratorProps(
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
                        hintText: 'Select a client',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      baseStyle: const TextStyle(fontSize: 14),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      containerBuilder: (context, popupWidget) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: popupWidget,
                        );
                      },
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Search child...',
                          hintStyle: const TextStyle(fontSize: 14),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      itemBuilder: (context, item, isDisabled, isSelected) {
                        final child = _children.firstWhere((c) => c['id'] == item);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            child['name'],
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      },
                    ),
                    itemAsString: (String id) {
                      final child = _children.firstWhere((c) => c['id'] == id);
                      return child['name'];
                    },
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedChildId = value;
                          final selectedChild = _children.firstWhere((child) => child['id'] == value);
                          _selectedChildName = selectedChild['name'];
                          // _parentNameController.text = selectedChild['parentName'] ?? '';
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a child';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Parent's Name
                // const Text(
                //   "Parent's Name",
                //   style: TextStyle(
                //     fontSize: 14,
                //     fontWeight: FontWeight.w400,
                //     color: Colors.black87,
                //   ),
                // ),
                // const SizedBox(height: 8),
                // Container(
                //   decoration: BoxDecoration(
                //     color: Colors.white,
                //     borderRadius: BorderRadius.circular(8),
                //   ),
                //   child: TextFormField(
                //     controller: _parentNameController,
                //     // readOnly: true,
                //     style: const TextStyle(
                //       fontSize: 14,
                //     ),
                //     cursorColor: Colors.black,
                //     validator: (value) {
                //       if (value == null || value.trim().isEmpty) {
                //         return 'Please enter parent\'s name';
                //       }
                //       return null;
                //     },
                //     decoration: InputDecoration(
                //       hintText: 'George Osieko',
                //       hintStyle: TextStyle(
                //         color: Colors.grey[400],
                //         fontSize: 14,
                //       ),
                //       border: OutlineInputBorder(
                //         borderRadius: BorderRadius.circular(8),
                //         borderSide: BorderSide.none,
                //       ),
                //       errorBorder: OutlineInputBorder(
                //         borderRadius: BorderRadius.circular(8),
                //         borderSide: const BorderSide(color: Colors.red, width: 1),
                //       ),
                //       contentPadding: const EdgeInsets.symmetric(
                //         horizontal: 16,
                //         vertical: 14,
                //       ),
                //     ),
                //   ),
                // ),
                // const SizedBox(height: 20),

                // Tracks Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tracks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _navigateToAddTrack,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Track'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Display added tracks
                if (_selectedTracks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // color: Colors.white,
                      // borderRadius: BorderRadius.circular(8),
                      // border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Center(
                      child: Text(
                        'No tracks added yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedTracks.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final track = _selectedTracks[index];
                      return Container(
                        decoration: BoxDecoration(
                          // color: Colors.white,
                          // borderRadius: BorderRadius.circular(8),
                          // border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      track.trackName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _editTrack(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                    onPressed: () => _removeTrack(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            if (track.objectives.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // const Divider(height: 1),
                                    // const SizedBox(height: 8),
                                    Text(
                                      'Objectives:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...track.objectives.asMap().entries.map((entry) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${entry.key + 1}. ${entry.value}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // Start Session Button
                CustomButton(text: 'Start Session', onPressed: _startSession, isLoading: _isSaving,),
              ],
            ),
          ),
        ),
      ),
    );
  }
}