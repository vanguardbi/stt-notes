import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_speech/google_speech.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class RecordingSessionScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String parentName;
  final String track;
  final String notes;

  const RecordingSessionScreen({
    Key? key,
    required this.childId,
    required this.childName,
    required this.parentName,
    required this.track,
    required this.notes,
  }) : super(key: key);

  @override
  State<RecordingSessionScreen> createState() => _RecordingSessionScreenState();
}

class _RecordingSessionScreenState extends State<RecordingSessionScreen> {
  FlutterSoundPlayer? audioPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder? _mRecorder = FlutterSoundRecorder();
  final StopWatchTimer _stopWatchTimer = StopWatchTimer();

  final Codec _codec = Codec.pcm16WAV;
  final String _fileExtension = 'wav';

  // Recording stages
  RecordingStage _currentStage = RecordingStage.initial;
  String? _recordedFilePath;
  String? _downloadURL;
  String? _transcriptText;
  int _recordingDuration = 0;
  bool _isGeneratingTranscript = false;

  @override
  void initState() {
    super.initState();
    openTheRecorder();
    audioPlayer!.openPlayer();
  }

  @override
  void dispose() async {
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
      throw Exception('Microphone permission denied');
    }
    await _mRecorder!.openRecorder();
  }

  Future<Directory> getDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  void startRecording() async {
    Directory applicationDirectory = await getDirectory();
    bool? canVibrate = await Vibration.hasVibrator();

    _mRecorder!
        .startRecorder(
      toFile: '${applicationDirectory.path}/temp.$_fileExtension',
      codec: _codec,
    )
        .then((_) async {
      _stopWatchTimer.onStartTimer();
      await WakelockPlus.enable();
      if (canVibrate == true) {
        Vibration.vibrate(duration: 100);
      }
      setState(() {
        _currentStage = RecordingStage.recording;
      });
    });
  }

  void pauseRecording() async {
    await _mRecorder!.pauseRecorder().then((_) async {
      bool? canVibrate = await Vibration.hasVibrator();
      if (canVibrate == true) {
        Vibration.vibrate(duration: 100);
      }
      setState(() {
        _stopWatchTimer.onStopTimer();
      });
      await WakelockPlus.disable();
    });
  }

  void resumeRecording() async {
    await _mRecorder!.resumeRecorder().then((_) async {
      bool? canVibrate = await Vibration.hasVibrator();
      if (canVibrate == true) {
        Vibration.vibrate(duration: 100);
      }
      setState(() {
        _stopWatchTimer.onStartTimer();
      });
      await WakelockPlus.enable();
    });
  }

  void stopRecording() async {
    await _mRecorder!.stopRecorder().then((value) async {
      bool? canVibrate = await Vibration.hasVibrator();
      if (canVibrate == true) {
        Vibration.vibrate(duration: 100);
      }

      _recordingDuration = _stopWatchTimer.rawTime.value;

      Directory applicationDirectory = await getDirectory();
      File audioFile = File('${applicationDirectory.path}/temp.$_fileExtension');

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '${widget.childName}_$timestamp';
      final renamedFile = await audioFile.rename('${applicationDirectory.path}/$fileName.$_fileExtension');

      await WakelockPlus.disable();

      setState(() {
        _recordedFilePath = renamedFile.path;
        _currentStage = RecordingStage.recordingComplete;
      });
    });
  }

  Future<void> generateTranscript() async {
    setState(() {
      _currentStage = RecordingStage.generatingTranscript;
      _isGeneratingTranscript = true;
    });

    try {
      // Upload to Firebase Storage first
      final storageRef = FirebaseStorage.instance.ref()
          .child('recordings/${widget.childName}_${DateTime.now().millisecondsSinceEpoch}.wav');

      final uploadTask = await storageRef.putFile(File(_recordedFilePath!));
      _downloadURL = await uploadTask.ref.getDownloadURL();

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

      final audioBytes = File(_recordedFilePath!).readAsBytesSync().toList();
      final response = await speechToText.recognize(config, audioBytes);

      _transcriptText = response.results
          .map((e) => e.alternatives.first.transcript)
          .join('\n');

      setState(() {
        _currentStage = RecordingStage.transcriptGenerated;
        _isGeneratingTranscript = false;
      });
    } catch (e) {
      setState(() {
        _isGeneratingTranscript = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> saveSessionToFirestore() async {
    try {
      await FirebaseFirestore.instance.collection('sessions').add({
        'childId': widget.childId,
        'childName': widget.childName,
        'parentName': widget.parentName,
        'track': widget.track,
        'notes': widget.notes,
        'audioUrl': _downloadURL,
        'duration': _recordingDuration,
        'transcript': _transcriptText ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session saved successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving session: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDuration(int milliseconds) {
    return StopWatchTimer.getDisplayTime(milliseconds, hours: true, milliSecond: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE0E0E0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStage) {
      case RecordingStage.initial:
      case RecordingStage.recording:
        return 'Recording';
      case RecordingStage.recordingComplete:
        return 'Recording Complete';
      case RecordingStage.generatingTranscript:
        return 'Generating Transcript';
      case RecordingStage.transcriptGenerated:
        return 'Transcript Generated';
      case RecordingStage.viewingSession:
        return 'Session';
    }
  }

  Widget _buildBody() {
    switch (_currentStage) {
      case RecordingStage.initial:
        return _buildInitialView();
      case RecordingStage.recording:
        return _buildRecordingView();
      case RecordingStage.recordingComplete:
        return _buildRecordingCompleteView();
      case RecordingStage.generatingTranscript:
        return _buildGeneratingTranscriptView();
      case RecordingStage.transcriptGenerated:
        return _buildTranscriptGeneratedView();
      case RecordingStage.viewingSession:
        return _buildViewSessionView();
    }
  }

  // Stage 1: Initial - Start Session Button
  Widget _buildInitialView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              child: ElevatedButton(
                onPressed: startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD0D0D0),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Start Session', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Stage 2: Recording View
  Widget _buildRecordingView() {
    final isRecording = _mRecorder?.isRecording ?? false;
    final isPaused = _mRecorder?.isPaused ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Timer
            StreamBuilder<int>(
              stream: _stopWatchTimer.rawTime,
              initialData: _stopWatchTimer.rawTime.value,
              builder: (context, snapshot) {
                final value = snapshot.data!;
                final displayTime = StopWatchTimer.getDisplayTime(value, hours: true, milliSecond: false);
                return Text(
                  displayTime,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87),
                );
              },
            ),

            const SizedBox(height: 48),

            // Waveform placeholder
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
              mainAxisAlignment: MainAxisAlignment.center,
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
          ],
        ),
      ),
    );
  }

  // Stage 3: Recording Complete View
  Widget _buildRecordingCompleteView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.childName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recording Saved',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: generateTranscript,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD0D0D0),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Generate Transcript', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Stage 4: Generating Transcript View
  Widget _buildGeneratingTranscriptView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.childName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
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

  // Stage 5: Transcript Generated View
  Widget _buildTranscriptGeneratedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.childName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            const Text(
              'Transcript Generated',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  saveSessionToFirestore();
                  setState(() {
                    _currentStage = RecordingStage.viewingSession;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD0D0D0),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View Micah\'s Session', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Stage 6: View Session Details
  Widget _buildViewSessionView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Child Name Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    widget.childName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Display Name
            const Text('Display Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.childName, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),

            // Parent's Name
            const Text("Parent's Name", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.parentName, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),

            // Listen to Recording Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Play audio
                  if (_recordedFilePath != null) {
                    audioPlayer!.startPlayer(fromURI: _recordedFilePath!);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD0D0D0),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Listen to Recording', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(height: 20),

            // Notes
            const Text('Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.notes.isEmpty ? 'No notes' : widget.notes, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),

            // Transcript
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
              child: Text(_transcriptText ?? 'No transcript available', style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),

            // Summary
            const Text('Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 100),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('AI-generated summary will appear here', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

enum RecordingStage {
  initial,
  recording,
  recordingComplete,
  generatingTranscript,
  transcriptGenerated,
  viewingSession,
}