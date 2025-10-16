import 'dart:async';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:google_speech/google_speech.dart';
import 'package:flutter/services.dart';
import 'package:stt/utils/utils.dart';

class RecScreen extends StatefulWidget {
  const RecScreen({super.key});

  @override
  State<RecScreen> createState() => _RecScreenState();
}

typedef Fn = void Function();

class _RecScreenState extends State<RecScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  FlutterSoundPlayer? audioPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder? _mRecorder = FlutterSoundRecorder();
  final StopWatchTimer _stopWatchTimer = StopWatchTimer();

  final Codec _codec = Codec.pcm16WAV;
  final String _fileExtension = 'wav';
  Duration duration = const Duration();

  bool isRecordingComplete = false;
  bool isGeneratingTranscript = false;
  bool isRecording = false;
  String? transcriptText;
  String? recordedFilePath;

  @override
  void initState() {
    super.initState();
    openTheRecorder();
    audioPlayer!.openPlayer();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    audioPlayer!.closePlayer();
    audioPlayer = null;

    _mRecorder!.closeRecorder();
    _mRecorder = null;

    _stopWatchTimer.dispose();
    super.dispose();
  }

  Future<void> openTheRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission denied');
    }
    await _mRecorder!.openRecorder();
  }

  // Start Recording
  void record() async {
    Directory? applicationDirectory = await getDirectory();
    bool? canVibrate = await Vibration.hasVibrator();

    await _mRecorder!
        .startRecorder(
      toFile: '${applicationDirectory.path}/temp.$_fileExtension',
      codec: _codec,
    )
        .then((_) async {
      _stopWatchTimer.onStartTimer();
      await WakelockPlus.enable();
      if (canVibrate == true) Vibration.vibrate(duration: 100);
      setState(() {
        isRecording = true;
      });
    });
  }

  // Stop Recording
  void stopRecorder() async {
    await _mRecorder!.stopRecorder().then((value) async {
      bool? canVibrate = await Vibration.hasVibrator();
      if (canVibrate == true) Vibration.vibrate(duration: 100);

      Directory? applicationDirectory = await getDirectory();
      File audioFile =
      File('${applicationDirectory.path}/temp.$_fileExtension');
      final newTitle = DateFormat('HHmmss').format(DateTime.now());
      final renamed = await audioFile.rename(
          '${applicationDirectory.path}/$newTitle.$_fileExtension');

      recordedFilePath = renamed.path;

      setState(() {
        _stopWatchTimer.onStopTimer();
        _stopWatchTimer.onResetTimer();
        isRecordingComplete = true;
        isRecording = false;
      });
      await WakelockPlus.disable();
    });
  }

  // Pause & Resume Recording
  void pauseRecorder() async {
    await _mRecorder!.pauseRecorder();
    setState(() {
      _stopWatchTimer.onStopTimer();
    });
  }

  void resumeRecorder() async {
    await _mRecorder!.resumeRecorder();
    setState(() {
      _stopWatchTimer.onStartTimer();
    });
  }

  Fn? getRecorderFn() {
    if (_mRecorder!.isRecording) {
      return pauseRecorder;
    } else if (_mRecorder!.isPaused) {
      return resumeRecorder;
    } else {
      return record;
    }
  }

  // 🔊 TRANSCRIBE USING GOOGLE SPEECH API
  Future<void> transcribeRecording() async {
    if (recordedFilePath == null) return;
    setState(() => isGeneratingTranscript = true);

    try {
      final serviceAccount = ServiceAccount.fromString(
          (await rootBundle.loadString('assets/cloud.json')));
      final speechToText = SpeechToText.viaServiceAccount(serviceAccount);

      final config = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        model: RecognitionModel.basic,
        enableAutomaticPunctuation: true,
        sampleRateHertz: 16000,
        languageCode: 'en-US',
      );

      final audioBytes = File(recordedFilePath!).readAsBytesSync().toList();
      final response = await speechToText.recognize(config, audioBytes);

      setState(() {
        transcriptText = response.results
            .map((e) => e.alternatives.first.transcript)
            .join('\n');
      });
    } catch (e) {
      Logger().e("Transcription error: $e");
    } finally {
      setState(() => isGeneratingTranscript = false);
    }
  }

  // 🎨 --- BUILD UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: buildRecordingState(context),
          ),
        ),
      ),
    );
  }

  Widget buildRecordingState(BuildContext context) {
    // Initial state
    if (!isRecording && !isRecordingComplete && transcriptText == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Ready to Record",
            style: GoogleFonts.raleway(
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: record,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            ),
            child: Text(
              "Record a Session",
              style: GoogleFonts.raleway(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      );
    }

    // Recording state
    if (isRecording) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StreamBuilder<int>(
            stream: _stopWatchTimer.rawTime,
            initialData: _stopWatchTimer.rawTime.value,
            builder: (context, snapshot) {
              final displayTime = StopWatchTimer.getDisplayTime(
                snapshot.data!,
                milliSecond: false,
              );
              return Text(
                displayTime,
                style: GoogleFonts.robotoMono(
                    fontSize: 42, fontWeight: FontWeight.w600),
              );
            },
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _mRecorder!.isPaused
                      ? Icons.play_circle_fill
                      : Icons.pause_circle_filled,
                  size: 64,
                ),
                onPressed: getRecorderFn(),
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.stop_circle, size: 64),
                onPressed: stopRecorder,
              ),
            ],
          ),
        ],
      );
    }

    // After recording complete
    if (isRecordingComplete && !isGeneratingTranscript && transcriptText == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic, size: 80),
          const SizedBox(height: 20),
          Text(
            "Recording Complete",
            style: GoogleFonts.raleway(
                fontSize: 24, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: transcribeRecording,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            ),
            child: Text(
              "Generate Transcript",
              style: GoogleFonts.raleway(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
        ],
      );
    }

    // While generating transcript
    if (isGeneratingTranscript) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Generating Transcript...",
            style: GoogleFonts.raleway(
                fontSize: 22, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 150,
            height: 8,
            child: LoadingIndicator(
              indicatorType: Indicator.lineScalePulseOutRapid,
              colors: [Colors.deepPurpleAccent, Colors.black],
            ),
          ),
        ],
      );
    }

    // Transcript generated
    if (transcriptText != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 20),
          Text(
            "Transcript Generated",
            style: GoogleFonts.raleway(
                fontSize: 24, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                transcriptText!,
                textAlign: TextAlign.center,
                style: GoogleFonts.raleway(
                  fontSize: 20,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
