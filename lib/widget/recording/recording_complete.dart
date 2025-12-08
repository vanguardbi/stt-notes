import 'package:flutter/material.dart';
import 'package:stt/utils/utils.dart';
import 'package:stt/widget/custom_button.dart';

class RecordingCompleteView extends StatelessWidget {
  const RecordingCompleteView({
    super.key,
    required this.childName,
    required this.recordingDuration,
    required this.isSavingSession,
    required this.onUpdateOutcomes
  });

  final String childName;
  final int recordingDuration; // Duration in milliseconds
  final bool isSavingSession;
  final VoidCallback onUpdateOutcomes;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40.0, left: 24.0, right: 24.0, bottom: 24.0),
        child: Column(
          children: [
            Text(
              childName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(
              formatDuration(recordingDuration),
              style: const TextStyle(fontSize: 64, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              isSavingSession ? 'Saving session...' : 'Recording Complete',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Update Session Observations',
                onPressed: isSavingSession ? null : onUpdateOutcomes,
                isLoading: isSavingSession,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
