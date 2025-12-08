import 'package:flutter/material.dart';
import 'package:stt/widget/custom_button.dart';

class ViewSessionView extends StatelessWidget {
  const ViewSessionView({
    super.key,
    required this.childName,
    required this.parentName,
    required this.notes,
    this.downloadURL,
    this.transcriptText,
    this.sessionOutcomes,
    this.nextSessionPlans,
    this.docUrl,
    required this.onListenToRecording,
    required this.onOpenTranscriptUrl
  });

  final String childName;
  final String parentName;
  final String notes;
  final String? downloadURL;
  final String? transcriptText;
  final String? sessionOutcomes;
  final String? nextSessionPlans;
  final String? docUrl;
  final VoidCallback onListenToRecording;
  final VoidCallback onOpenTranscriptUrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            const Text('Child\'s Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(childName, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),

            const Text("Parent's Name", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(parentName, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),

            // Listen to Recording Button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Listen to Recording',
                onPressed: onListenToRecording,
              ),
            ),
            const SizedBox(height: 20),

            const Text('Objectives', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(notes.isEmpty ? 'No objectives' : notes, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),

            const Text('Transcript', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(transcriptText ?? 'No transcript available', style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),

            const Text('Outcomes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 100),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(sessionOutcomes ?? '', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),

            const Text('Plans for Next Session', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 100),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(nextSessionPlans ?? '', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),

            const Text('Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'View Summary in Google Docs',
                onPressed: docUrl != null && docUrl!.isNotEmpty
                    ? onOpenTranscriptUrl
                    : null,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
