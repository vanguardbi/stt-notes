import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_speech/google_speech.dart';

class SimpleAudioTestPage extends StatefulWidget {
  const SimpleAudioTestPage({Key? key}) : super(key: key);

  @override
  State<SimpleAudioTestPage> createState() => _SimpleAudioTestPageState();
}

class _SimpleAudioTestPageState extends State<SimpleAudioTestPage> {
  late FlutterSoundRecorder _recorder;
  String? _recordedFilePath;
  String? _transcript;
  bool _isRecording = false;
  bool _isTranscribing = false;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      await Permission.microphone.request();
      await Permission.storage.request();

      _recorder = FlutterSoundRecorder();
      await _recorder.openRecorder();
    } catch (e) {
      print('Init error: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      setState(() => _isRecording = true);

      Directory dir = await getApplicationDocumentsDirectory();
      _recordedFilePath = '${dir.path}/test_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.startRecorder(
        toFile: _recordedFilePath,
        codec: Codec.pcm16WAV,
        audioSource: AudioSource.microphone,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      );
    } catch (e) {
      print('Record error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stopRecorder();
      setState(() => _isRecording = false);
    } catch (e) {
      print('Stop error: $e');
    }
  }

  Future<void> _generateTranscript() async {
    if (_recordedFilePath == null) return;

    setState(() => _isTranscribing = true);

    try {
      File file = File(_recordedFilePath!);
      final serviceAccountJson = await rootBundle.loadString('assets/cloud.json');
      final serviceAccount = ServiceAccount.fromString(serviceAccountJson);
      final speechToText = SpeechToText.viaServiceAccount(serviceAccount);

      final config = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        model: RecognitionModel.basic,
        enableAutomaticPunctuation: true,
        sampleRateHertz: 16000,
        languageCode: 'en-US',
      );

      final audioBytes = await file.readAsBytes();
      final response = await speechToText.recognize(config, audioBytes);

      String transcript = '';
      if (response.results.isNotEmpty) {
        transcript = response.results
            .map((result) => result.alternatives.isNotEmpty
            ? result.alternatives.first.transcript
            : '')
            .join('\n');
      }

      setState(() {
        _transcript = transcript.isEmpty ? 'No speech detected' : transcript;
        _isTranscribing = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() => _isTranscribing = false);
    }
  }

  @override
  void dispose() async {
    await _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE0E0E0),
        elevation: 0,
        title: const Text('Audio Test', style: TextStyle(color: Colors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRecording ? null : _startRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD0D0D0),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Start', style: TextStyle(color: Colors.black87, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: !_isRecording ? null : _stopRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD0D0D0),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Stop', style: TextStyle(color: Colors.black87, fontSize: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_recordedFilePath == null || _isTranscribing) ? null : _generateTranscript,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD0D0D0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _isTranscribing ? 'Generating...' : 'Generate Transcript',
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 48),
            if (_transcript != null)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(_transcript!, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}