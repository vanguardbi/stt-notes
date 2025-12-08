import 'package:flutter/material.dart';
import 'package:stt/widget/custom_button.dart';

class RecordingOutcomesView extends StatefulWidget {
  const RecordingOutcomesView({
    super.key,
    required this.recordingDuration,
    required this.outcomesController,
    required this.plansController,
    required this.sessionSaved,
    required this.onSaveDetails,
    required this.onGenerateTranscript
  });

  final int recordingDuration;
  final TextEditingController outcomesController;
  final TextEditingController plansController;
  final bool sessionSaved;
  final VoidCallback onSaveDetails;
  final VoidCallback onGenerateTranscript;

  @override
  State<RecordingOutcomesView> createState() => _RecordingOutcomesViewState();
}

class _RecordingOutcomesViewState extends State<RecordingOutcomesView> {
  final _sessionFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _sessionFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Outcomes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: widget.outcomesController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Session outcomes are required";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                const Text(
                  'Plans for Next Session',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: widget.plansController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Plans for next session are required";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Save Session',
                    onPressed: () async {
                      if (_sessionFormKey.currentState!.validate()) {
                        widget.onSaveDetails();
                      }
                    },
                  ),
                ),

                const SizedBox(height: 16),

                if (widget.sessionSaved)
                  SizedBox(
                    width: double.infinity,
                    // child: CustomButton(
                    //   text: 'View Session',
                    //   onPressed: () {
                    //     setState(() {
                    //       _currentStage = RecordingStage.viewingSession;
                    //     });
                    //   },
                    // ),
                    child: CustomButton(text: 'Generate Transcript', onPressed: widget.onGenerateTranscript,),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
