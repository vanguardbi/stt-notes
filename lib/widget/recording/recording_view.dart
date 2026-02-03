import 'package:flutter/material.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

class RecordingView extends StatelessWidget {
  const RecordingView({
    super.key,
    required this.isRecording,
    required this.stopWatchTimer,
    required this.pauseRecording,
    required this.resumeRecording,
    required this.stopRecording,
    required this.notesController
  });

  final bool isRecording;
  final StopWatchTimer stopWatchTimer;
  final VoidCallback pauseRecording;
  final VoidCallback resumeRecording;
  final VoidCallback stopRecording;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0, left: 24.0, right: 24.0, bottom: 24.0),
          child: Column(
            children: [
              StreamBuilder<int>(
                stream: stopWatchTimer.rawTime,
                initialData: stopWatchTimer.rawTime.value,
                builder: (context, snapshot) {
                  final value = snapshot.data!;
                  final displayTime = StopWatchTimer.getDisplayTime(value, hours: true, milliSecond: false);
                  return Text(
                    displayTime,
                    style: const TextStyle(fontSize: 64, color: Colors.black87),
                  );
                },
              ),

              const SizedBox(height: 48),

              // Waveform
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Icon(Icons.graphic_eq, size: 80, color: Colors.grey[400]),
                ),
              ),

              const SizedBox(height: 48),

              // Control buttons
              Row(
                children: [
                  // Pause/Resume button
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(isRecording ? Icons.pause : Icons.play_arrow, size: 30),
                      onPressed: isRecording ? pauseRecording : resumeRecording,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Stop button
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.stop, size: 30),
                      onPressed: stopRecording,
                    ),
                  ),
                ],
              ),

              // const SizedBox(height: 32),

              if (!isRecording) ...[
                const SizedBox(height: 40),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Session Notes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notesController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type your observations here...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
