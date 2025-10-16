import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stt/widget/custom_button.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_speech/google_speech.dart';

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
  late FlutterSoundPlayer _audioPlayer;
  late FlutterSoundRecorder _recordingSession;
  final StopWatchTimer _stopWatchTimer = StopWatchTimer();

  final Codec _codec = Codec.aacADTS;
  final String _fileExtension = 'aac';

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
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    _audioPlayer = FlutterSoundPlayer();
    _recordingSession = FlutterSoundRecorder();

    await Permission.microphone.request();
    await _audioPlayer.openPlayer();
    await _recordingSession.openRecorder();
    final isSupported = await _recordingSession.isEncoderSupported(Codec.pcm16WAV);
    print('Recorder initialized: WAV supported? $isSupported');
  }

  @override
  void dispose() async {
    await _stopWatchTimer.dispose();
    await _audioPlayer.closePlayer();
    await _recordingSession.closeRecorder();
    super.dispose();
  }

  Future<void> _checkMicPermission() async {
    var status = await Permission.microphone.status;
    print('status, $status');
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    if (!status.isGranted) {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<void> openTheRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission denied');
    }
  }

  Future<Directory> getDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  void startRecording() async {
    try {
      await _checkMicPermission();
      Directory applicationDirectory = await getDirectory();
      bool? canVibrate = await Vibration.hasVibrator();

      String filePath = '${applicationDirectory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.$_fileExtension';

      await _recordingSession.startRecorder(
        toFile: filePath,
        codec: _codec,
        audioSource: AudioSource.microphone,
        sampleRate: 16000,
      );
      await Future.delayed(const Duration(milliseconds: 500));

      _stopWatchTimer.onStartTimer();
      await WakelockPlus.enable();
      if (canVibrate == true) {
        Vibration.vibrate(duration: 100);
      }

      setState(() {
        _currentStage = RecordingStage.recording;
        _recordedFilePath = filePath;
      });
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void pauseRecording() async {
    try {
      await _recordingSession.pauseRecorder();
      bool? canVibrate = await Vibration.hasVibrator();
      if (canVibrate == true) {
        Vibration.vibrate(duration: 100);
      }
      setState(() {
        _stopWatchTimer.onStopTimer();
      });
      await WakelockPlus.disable();
    } catch (e) {
      print('Error pausing recording: $e');
    }
  }

  void resumeRecording() async {
    try {
      await _recordingSession.resumeRecorder();
      bool? canVibrate = await Vibration.hasVibrator();
      if (canVibrate == true) {
        Vibration.vibrate(duration: 100);
      }
      setState(() {
        _stopWatchTimer.onStartTimer();
      });
      await WakelockPlus.enable();
    } catch (e) {
      print('Error resuming recording: $e');
    }
  }

  void stopRecording() async {
    try {
      await _recordingSession.stopRecorder();
      bool? canVibrate = await Vibration.hasVibrator();
      if (canVibrate == true) {
        Vibration.vibrate(duration: 100);
      }

      _recordingDuration = _stopWatchTimer.rawTime.value;

      await WakelockPlus.disable();

      setState(() {
        _currentStage = RecordingStage.recordingComplete;
      });
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
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

      final inputPath = _recordedFilePath!;
      final outputPath = inputPath.replaceAll('.aac', '.wav');

      await FFmpegKit.execute(
          '-y -i ${_recordedFilePath!} -ac 1 -ar 16000 -acodec pcm_s16le -af loudnorm ${_recordedFilePath!.replaceAll(".aac", ".wav")}'
      );
      _recordedFilePath = outputPath;
      print('Converted to WAV: ${await File(outputPath).length()} bytes');

      final audioBytes = File(_recordedFilePath!).readAsBytesSync().toList();
      print('Audio data size (bytes): ${audioBytes.length}');
      final response = await speechToText.recognize(config, audioBytes);
      print('response: $response');

      _transcriptText = response.results
          .map((e) => e.alternatives.first.transcript)
          .join('\n');
      print('transcriptText: $_transcriptText');

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
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No user logged in');
      }

      final docRef = FirebaseFirestore.instance.collection('sessions').doc();
      await docRef.set({
        'id': docRef.id,
        'childId': widget.childId,
        'childName': widget.childName,
        'parentName': widget.parentName,
        'track': widget.track,
        'notes': widget.notes,
        'audioUrl': _downloadURL,
        'duration': _recordingDuration,
        'transcript': _transcriptText ?? '',
        'createdBy': user.uid,
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
        backgroundColor: const Color(0xFFFF5959),
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
        return '${widget.childName}';
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

  // Stage 2: Recording View
  Widget _buildRecordingView() {
    final isRecording = _recordingSession.isRecording;
    final isPaused = _recordingSession.isPaused;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40.0, left: 24.0, right: 24.0, bottom: 24.0),
        child: Column(
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
                  style: const TextStyle(fontSize: 64, color: Colors.black87),
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
        // padding: const EdgeInsets.all(24.0),
        padding: const EdgeInsets.only(top: 40.0, left: 24.0, right: 24.0, bottom: 24.0),
        child: Column(
          children: [
            Text(
              widget.childName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(fontSize: 64, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            const Text(
              'Recording Complete',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: CustomButton(text: 'Generate Transcript', onPressed: generateTranscript,),
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
        // padding: const EdgeInsets.all(24.0),
        padding: const EdgeInsets.only(top: 40.0, left: 24.0, right: 24.0, bottom: 24.0),
        child: Column(
          children: [
            Text(
              widget.childName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Text(
              _formatDuration(_recordingDuration),
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

  // Stage 5: Transcript Generated View
  Widget _buildTranscriptGeneratedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              widget.childName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Text(
              _formatDuration(_recordingDuration),
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
              child: CustomButton(
                text: 'View Session',
                onPressed: () {
                  saveSessionToFirestore();
                  setState(() {
                    _currentStage = RecordingStage.viewingSession;
                  });
                },
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
            const SizedBox(height: 20),

            // Display Name
            const Text('Child\'s Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
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
              child: CustomButton(
                text: 'Listen to Recording',
                onPressed: () async {
                  // Play audio
                  if (_recordedFilePath != null) {
                    try {
                      await _audioPlayer.startPlayer(fromURI: _recordedFilePath!);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error playing audio: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
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