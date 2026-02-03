import 'package:flutter/material.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

enum RecordingStage {
  initial,
  recording,
  recordingComplete,
  generatingTranscript,
  transcriptGenerated,
  detailsUpdate,
  viewingSession,
}

String formatDuration(int milliseconds) {
  return StopWatchTimer.getDisplayTime(milliseconds, hours: true, milliSecond: false);
}

class TextLabel extends StatelessWidget {
  const TextLabel({
    super.key,
    required this.labelName,
  });

  final String labelName;

  @override
  Widget build(BuildContext context) {
    return Text(labelName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400));
  }
}

class InputBoxContainer extends StatelessWidget {
  const InputBoxContainer({
    super.key,
    required this.inputText,
    this.color,
  });

  final String inputText;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(inputText, style: const TextStyle(fontSize: 14)),
    );
  }
}

class TrackWithObjectives {
  final String trackName;
  final List<String> objectives;

  TrackWithObjectives({
    required this.trackName,
    required this.objectives,
  });

  Map<String, dynamic> toMap() {
    return {
      'trackName': trackName,
      'objectives': objectives,
    };
  }

  factory TrackWithObjectives.fromMap(Map<String, dynamic> map) {
    return TrackWithObjectives(
      trackName: map['trackName'] ?? '',
      objectives: List<String>.from(map['objectives'] ?? []),
    );
  }

  @override
  String toString() {
    return 'TrackWithObjectives(trackName: $trackName, objectives: $objectives)';
  }
}