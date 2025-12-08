import 'package:flutter/material.dart';
import 'package:stt/utils/utils.dart';
import 'package:stt/widget/custom_button.dart';

class GeneratedTranscriptView extends StatelessWidget {
  const GeneratedTranscriptView({
    super.key,
    required this.childName,
    required this.recordingDuration,
    required this.onViewSession
  });

  final String childName;
  final int recordingDuration;
  final VoidCallback onViewSession;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              childName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Text(
              formatDuration(recordingDuration),
              style: const TextStyle(fontSize: 64, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            const Text(
              'Transcript Generated',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              // child: CustomButton(
              //   text: 'Update Session Outcomes',
              //   onPressed: () {
              //     setState(() {
              //       _currentStage = RecordingStage.detailsUpdate;
              //     });
              //   },
              // ),
              child: CustomButton(
                text: 'View Session',
                onPressed: onViewSession,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
