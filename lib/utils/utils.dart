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