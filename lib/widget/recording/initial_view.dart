import 'package:flutter/material.dart';
import 'package:stt/widget/custom_button.dart';

class InitialRecordingView extends StatelessWidget {
  const InitialRecordingView({
    super.key,
    required this.startRecording,
  });

  final VoidCallback startRecording;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40.0, left: 24.0, right: 24.0, bottom: 24.0),
        child: Column(
          children: [
            Icon(Icons.mic, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Ready to record',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: CustomButton(text: 'Start Session', onPressed: startRecording,),
            ),
          ],
        ),
      ),
    );
  }
}
