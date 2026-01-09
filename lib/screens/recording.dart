import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:stt/utils/utils.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/recording/generated_transcript.dart';
import 'package:stt/widget/recording/generating_transcript.dart';
import 'package:stt/widget/recording/initial_view.dart';
import 'package:stt/widget/recording/recording_complete.dart';
import 'package:stt/widget/recording/recording_outcomes.dart';
import 'package:stt/widget/recording/recording_view.dart';
import 'package:stt/widget/recording/view_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

class RecordingSessionScreen extends StatefulWidget {
  final String childId;
  final String childName;
  // final String parentName;
  final List<TrackWithObjectives> tracks;

  const RecordingSessionScreen({
    Key? key,
    required this.childId,
    required this.childName,
    // required this.parentName,
    required this.tracks,
  }) : super(key: key);

  @override
  State<RecordingSessionScreen> createState() => _RecordingSessionScreenState();
}

class _RecordingSessionScreenState extends State<RecordingSessionScreen> {
  late FlutterSoundPlayer _audioPlayer;
  final StopWatchTimer _stopWatchTimer = StopWatchTimer();

  final RecorderStream _recorder = RecorderStream();
  StreamSubscription? _audioSubscription;

  IOWebSocketChannel? _deepgramChannel;
  IOSink? _fileSink;

  final _supabase = Supabase.instance.client;

  final int _sampleRate = 16000;
  final String _fileExtension = 'wav';
  final String _deepgramApiKey = '';

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

    await Permission.microphone.request();
    await _audioPlayer.openPlayer();

    await _recorder.initialize();
    print('Recorder initialized');
  }

  @override
  void dispose() async {
    _audioSubscription?.cancel();
    _deepgramChannel?.sink.close();
    _stopWatchTimer.dispose();
    _fileSink?.close();
    _cleanupResources();
    super.dispose();
  }

  Future<void> _cleanupResources() async {
    try {
      await _recorder.stop();
      await _audioPlayer.closePlayer();
      await _cleanupTempFiles();
    } catch (e) {
      print('Error during resource cleanup: $e');
    }
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
      Directory appDir = await getApplicationDocumentsDirectory();
      bool? canVibrate = await Vibration.hasVibrator();

      // 1. Prepare File
      String filePath = '${appDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.$_fileExtension';
      File file = File(filePath);
      if (file.existsSync()) await file.delete();
      _fileSink = file.openWrite(); // Open stream to write bytes

      // 2. Connect to Deepgram
      final deepgramUrl = Uri.parse('wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=$_sampleRate&language=en&smart_format=true');
      _deepgramChannel = IOWebSocketChannel.connect(
        deepgramUrl,
        headers: {'Authorization': 'Token $_deepgramApiKey'},
      );

      // 3. Listen for Transcripts
      _deepgramChannel!.stream.listen((message) {
        _handleDeepgramResponse(message);
      }, onError: (e) => print('Deepgram error: $e'));

      // 4. Start Mic Stream & Split Data
      _audioSubscription = _recorder.audioStream.listen((data) {
        // A. Send to Deepgram
        _deepgramChannel?.sink.add(data);
        // B. Write to Local File
        _fileSink?.add(data);
      });

      await _recorder.start();

      // UI Updates
      await Future.delayed(const Duration(milliseconds: 500));
      _stopWatchTimer.onStartTimer();
      await WakelockPlus.enable();
      if (canVibrate == true) Vibration.vibrate(duration: 100);

      setState(() {
        _currentStage = RecordingStage.recording;
        _recordedFilePath = filePath;
        _transcriptText = ""; // Reset transcript
      });
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _handleDeepgramResponse(dynamic message) {
    try {
      Map<String, dynamic> json = jsonDecode(message);
      var alternatives = json['channel']['alternatives'] as List;
      bool isFinal = json['is_final'] ?? false;

      if (alternatives.isNotEmpty) {
        String transcript = alternatives[0]['transcript'] ?? '';
        if (transcript.isNotEmpty && isFinal) {
          setState(() {
            _transcriptText = (_transcriptText ?? "") + " " + transcript;
          });
          print("Live Transcript: $_transcriptText");
        }
      }
    } catch (e) {
      // Ignore keep-alive or malformed json
    }
  }

  void pauseRecording() async {
    try {
      await _recorder.stop();
      _stopWatchTimer.onStopTimer();
      await WakelockPlus.disable();
      setState(() {});
    } catch (e) {
      print('Error pausing recording: $e');
    }
  }

  void resumeRecording() async {
    try {
      await _recorder.start();
      _stopWatchTimer.onStartTimer();
      await WakelockPlus.enable();
      setState(() {});
    } catch (e) {
      print('Error resuming recording: $e');
    }
  }

  void stopRecording() async {
    try {
      await _recorder.stop();
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      _deepgramChannel?.sink.add(jsonEncode({'type': 'CloseStream'}));
      await _deepgramChannel?.sink.close();
      _deepgramChannel = null;

      await _fileSink?.flush();
      await _fileSink?.close();
      _fileSink = null;

      if (_recordedFilePath != null) {
        await _addWavHeader(_recordedFilePath!);
      }

      bool? canVibrate = await Vibration.hasVibrator();
      if (canVibrate == true) Vibration.vibrate(duration: 100);

      _recordingDuration = _stopWatchTimer.rawTime.value;
      await WakelockPlus.disable();

      setState(() {
        _currentStage = RecordingStage.recordingComplete;
      });

      await _saveSessionToFirestore();
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addWavHeader(String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    final pcmBytes = await file.readAsBytes();
    final header = _buildWavHeader(pcmBytes.length, _sampleRate);

    final bytesBuilder = BytesBuilder();
    bytesBuilder.add(header);
    bytesBuilder.add(pcmBytes);

    await file.writeAsBytes(bytesBuilder.toBytes(), flush: true);
    print("WAV Header added. Ready for upload.");
  }

  Uint8List _buildWavHeader(int dataLength, int sampleRate) {
    int channels = 1;
    int bitsPerSample = 16;
    int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    int blockAlign = channels * (bitsPerSample ~/ 8);
    int fileSize = dataLength + 36;

    final header = BytesBuilder();
    header.add("RIFF".codeUnits);
    header.add(_intToBytes(fileSize, 4));
    header.add("WAVE".codeUnits);
    header.add("fmt ".codeUnits);
    header.add(_intToBytes(16, 4));
    header.add(_intToBytes(1, 2));
    header.add(_intToBytes(channels, 2));
    header.add(_intToBytes(sampleRate, 4));
    header.add(_intToBytes(byteRate, 4));
    header.add(_intToBytes(blockAlign, 2));
    header.add(_intToBytes(bitsPerSample, 2));
    header.add("data".codeUnits);
    header.add(_intToBytes(dataLength, 4));
    return header.toBytes();
  }

  List<int> _intToBytes(int value, int length) {
    final ret = <int>[];
    for (var i = 0; i < length; i++) {
      ret.add(value & 0xFF);
      value >>= 8;
    }
    return ret;
  }

  Future<void> _saveSessionToFirestore() async {
    if (_isSavingSession) return;

    setState(() {
      _isSavingSession = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Please login first');
      }

      final fileName = '${widget.childId}_${DateTime.now().millisecondsSinceEpoch}.$_fileExtension';
      final storagePath = 'uploads/$fileName';

      print('Uploading file to Supabase Storage...');

      final file = File(_recordedFilePath!);

      await _supabase.storage
          .from('session_recordings')
          .upload(
        storagePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final String publicUrl = _supabase.storage
          .from('session_recordings')
          .getPublicUrl(storagePath);

      print('File uploaded: $publicUrl');
      _downloadURL = publicUrl;

      final tracksData = widget.tracks.map((track) => track.toMap()).toList();

      final response = await _supabase.from('sessions').insert({
        'child_id': widget.childId,
        'child_name': widget.childName,
        // 'parent_name': widget.parentName,
        'tracks': tracksData,
        'audio_url': _downloadURL,
        'duration': _recordingDuration ~/ 1000,
        'transcript': _transcriptText,
        'created_by': user.id,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      _sessionId = response['id'];
      print('Session saved with ID: $_sessionId');

      setState(() {
        _sessionId = response['id'];
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
    print(_transcriptText);
    // return;
    if (_sessionId == null) {
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

      final session = Supabase.instance.client.auth.currentSession;
      final accessToken = session?.accessToken;

      final tracksData = widget.tracks.map((track) => track.toMap()).toList();
      final plans = _plansController.text.trim();

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'transcript': _transcriptText,
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
      // await FirebaseFirestore.instance.collection("sessions").doc(_sessionId)
      //     .update({
      //   "outcomes": outcomes,
      //   "nextSessionPlans": plans,
      //   "updatedAt": FieldValue.serverTimestamp(),
      // });

      await _supabase.from('sessions').update({
        'outcomes': outcomes,
        'next_session_plans': plans,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _sessionId!);

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
    final isRecording = _currentStage == RecordingStage.recording;

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
        // parentName: widget.parentName,
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
