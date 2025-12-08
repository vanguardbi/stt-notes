import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stt/utils/utils.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/recording/generated_transcript.dart';
import 'package:stt/widget/recording/generating_transcript.dart';
import 'package:stt/widget/recording/initial_view.dart';
import 'package:stt/widget/recording/recording_complete.dart';
import 'package:stt/widget/recording/recording_outcomes.dart';
import 'package:stt/widget/recording/recording_view.dart';
import 'package:stt/widget/recording/view_session.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

  class RecordingSessionScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String parentName;
  final List<TrackWithObjectives> tracks;

  const RecordingSessionScreen({
    Key? key,
    required this.childId,
    required this.childName,
    required this.parentName,
    required this.tracks,
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

  final TextEditingController _outcomesController = TextEditingController();
  final TextEditingController _plansController = TextEditingController();

  // Recording stages
  RecordingStage _currentStage = RecordingStage.initial;
  String? _recordedFilePath;
  String? _downloadURL;
  String? _transcriptText;
  String? _docUrl;
  String? _aiSummary;
  String? _sessionOutcomes;
  String? _nextSessionPlans;
  bool _sessionSaved = false;
  String? _sessionId;
  int _recordingDuration = 0;
  bool _isGeneratingTranscript = false;
  bool _isSavingSession = false;

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
    await _cleanupTempFiles();
    await _stopWatchTimer.dispose();
    await _audioPlayer.closePlayer();
    await _recordingSession.closeRecorder();
    super.dispose();
  }

  Future<void> _cleanupTempFiles() async {
    try {
      if (_recordedFilePath != null) {
        final file = File(_recordedFilePath!);
        if (await file.exists()) {
          await file.delete();
          print('Cleaned up temp file: $_recordedFilePath');
        }
      }
    } catch (e) {
      print('Error cleaning up files: $e');
    }
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
      _stopWatchTimer.onStopTimer();
      await WakelockPlus.disable();
      setState(() {});
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
      _stopWatchTimer.onStartTimer();
      await WakelockPlus.enable();
      setState(() {});
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

      // Save session immediately after stopping
      await _saveSessionToFirestore();
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveSessionToFirestore() async {
    if (_isSavingSession) return;

    setState(() {
      _isSavingSession = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please login first');
      }

      // Upload audio to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref()
          .child('recordings/${widget.childId}_${DateTime.now().millisecondsSinceEpoch}.$_fileExtension');

      print('Uploading file to Storage...');
      final uploadTask = await storageRef.putFile(File(_recordedFilePath!));
      _downloadURL = await uploadTask.ref.getDownloadURL();
      print('File uploaded: $_downloadURL');

      final tracksData = widget.tracks.map((track) => track.toMap()).toList();

      // Create session document
      final docRef = FirebaseFirestore.instance.collection('sessions').doc();
      await docRef.set({
        'id': docRef.id,
        'childId': widget.childId,
        'childName': widget.childName,
        'parentName': widget.parentName,
        'tracks': tracksData,
        'audioUrl': _downloadURL,
        'duration': _recordingDuration ~/ 1000, // Convert to seconds
        'transcript': '', // Will be updated by Cloud Function
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _sessionId = docRef.id;
      print('Session saved with ID: $_sessionId');

      setState(() {
        _isSavingSession = false;
      });

    } catch (e) {
      print('Error saving session: $e');
      setState(() {
        _isSavingSession = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> generateTranscript() async {
    if (_sessionId == null || _downloadURL == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please start your session again'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _currentStage = RecordingStage.generatingTranscript;
      _isGeneratingTranscript = true;
    });

    try {
      print('Calling Cloud Function...');
      const functionUrl = String.fromEnvironment('FUNCTION_URL');

      if (functionUrl.isEmpty) {
        print('Error: FUNCTION_URL not configured');
        setState(() {
          _currentStage = RecordingStage.recordingComplete;
          _isGeneratingTranscript = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating transcript'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final tracksData = widget.tracks.map((track) => track.toMap()).toList();
      final plans = _plansController.text.trim();

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'audioUrl': _downloadURL,
          'childId': widget.childId,
          'sessionId': _sessionId,
          'name': widget.childName,
          'tracks': tracksData,
          'nextSessionPlans': plans,
        }),
      );

      final result = jsonDecode(response.body);

      // Check if success is true
      if (result['success'] != true) {
        setState(() {
          _currentStage = RecordingStage.recordingComplete;
          _isGeneratingTranscript = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating transcript'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Extract transcript from result
      final transcript = result['transcript'] ?? '';
      final transcriptConvo = result['formattedConversation'] ?? '';
      final aiSummary = result['summary'] ?? '';
      final docUrl = result['url'] ?? '';

      setState(() {
        _transcriptText = transcriptConvo;
        _docUrl = docUrl;
        _aiSummary = aiSummary;
        _currentStage = RecordingStage.transcriptGenerated;
        _isGeneratingTranscript = false;
      });

    } catch (e) {
      print('Error generating transcript: $e');

      setState(() {
        _isGeneratingTranscript = false;
        _currentStage = RecordingStage.recordingComplete;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _openTranscriptUrl() async {
    if (_docUrl == null || _docUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcript URL not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final Uri url = Uri.parse(_docUrl!);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error opening transcript URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening transcript: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveSessionDetails() async {
    final outcomes = _outcomesController.text.trim();
    final plans = _plansController.text.trim();

    try {
      await FirebaseFirestore.instance.collection("sessions").doc(_sessionId)
          .update({
        "outcomes": outcomes,
        "nextSessionPlans": plans,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      setState(() {
        _nextSessionPlans = plans;
        _sessionOutcomes= outcomes;
        _sessionSaved= true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session details saved"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving details"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(title: _getAppBarTitle(), showBack: true,),
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
      case RecordingStage.detailsUpdate:
        return 'Update Session';
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
      case RecordingStage.detailsUpdate:
        return _buildSessionDetailsFormView();
      case RecordingStage.viewingSession:
        return _buildViewSessionView();
    }
  }

  // Stage 1: Initial - Start Session Button
  Widget _buildInitialView() {
    return InitialRecordingView(startRecording: startRecording);
  }

  // Stage 2: Recording View
  Widget _buildRecordingView() {
    final isRecording = _recordingSession.isRecording;

    return RecordingView(
      isRecording: isRecording,
      stopWatchTimer: _stopWatchTimer,
      pauseRecording: pauseRecording,
      resumeRecording: resumeRecording,
      stopRecording: stopRecording
    );
  }

  // Stage 3: Recording Complete View
  Widget _buildRecordingCompleteView() {
    return RecordingCompleteView(
      childName: widget.childName,
      recordingDuration: _recordingDuration,
      isSavingSession: _isSavingSession,
      onUpdateOutcomes: () { setState(() { _currentStage = RecordingStage.detailsUpdate; }); }
    );
  }

  // Stage 4: Update session outcomes
  Widget _buildSessionDetailsFormView() {
    return RecordingOutcomesView(
      recordingDuration: _recordingDuration,
      outcomesController: _outcomesController,
      plansController: _plansController,
      sessionSaved: _sessionSaved,
      onSaveDetails: () async {
        await _saveSessionDetails();
      },
      onGenerateTranscript: generateTranscript,
    );
  }

  // Stage 5: Generating Transcript View
  Widget _buildGeneratingTranscriptView() {
    return GeneratingTranscriptView(childName: widget.childName, recordingDuration: _recordingDuration);
  }

  // Stage 6: Transcript Generated View
  Widget _buildTranscriptGeneratedView() {
    return GeneratedTranscriptView(
      childName: widget.childName,
      recordingDuration: _recordingDuration,
      onViewSession: () {
        setState(() {
          _currentStage = RecordingStage.viewingSession;
        });
      },
    );
  }

  // Stage 7: View Session Details
  Widget _buildViewSessionView() {
    return ViewSessionView(
        childName: widget.childName,
        parentName: widget.parentName,
        notes: '',
        downloadURL: _downloadURL,
        transcriptText: _transcriptText,
        sessionOutcomes: _sessionOutcomes,
        nextSessionPlans: _nextSessionPlans,
        docUrl: _docUrl,
        onListenToRecording: () async {
          if (_downloadURL != null) {
            try {
              await _audioPlayer.startPlayer(fromURI: _downloadURL!);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error playing audio: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
        onOpenTranscriptUrl: _openTranscriptUrl
    );
  }
}
