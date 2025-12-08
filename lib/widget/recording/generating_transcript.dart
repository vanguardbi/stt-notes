import 'package:flutter/material.dart';
import 'package:stt/utils/utils.dart';

class GeneratingTranscriptView extends StatelessWidget {
  const GeneratingTranscriptView({
    super.key,
    required this.childName,
    required this.recordingDuration
  });

  final String childName;
  final int recordingDuration;

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
            const SizedBox(height: 24),
            Text(
              formatDuration(recordingDuration),
              style: const TextStyle(fontSize: 64, color: Colors.black87),
            ),
            const SizedBox(height: 48),
            const LinearProgressIndicator(
              minHeight: 6,
              borderRadius: BorderRadius.all(Radius.circular(8)),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
              backgroundColor: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 24),
            const Text(
              'Generating Transcript...',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
