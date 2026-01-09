import 'package:flutter/material.dart';
import 'dart:async';
import 'package:stt/utils/utils.dart';

class GeneratingTranscriptView extends StatefulWidget {
  const GeneratingTranscriptView({
    super.key,
    required this.childName,
    required this.recordingDuration
  });

  final String childName;
  final int recordingDuration;

  @override
  State<GeneratingTranscriptView> createState() => _GeneratingTranscriptViewState();
}

class _GeneratingTranscriptViewState extends State<GeneratingTranscriptView> {
  int _currentTextIndex = 0;
  Timer? _timer;

  final List<String> _loadingTexts = [
    'Polishing your paragraphs and perfecting the punctuation.',
    'Structuring the text and aligning your timestamps.',
    "Teaching the AI the difference between 'their', 'there', and 'they're'.",
    "Dotting the i’s and crossing the t’s.",
    "Sorting out who said what, when.",
  ];

  @override
  void initState() {
    super.initState();
    _startTextRotation();
  }

  void _startTextRotation() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentTextIndex = (_currentTextIndex + 1) % _loadingTexts.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40.0, left: 24.0, right: 24.0, bottom: 24.0),
        child: Column(
          children: [
            Text(
              widget.childName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Text(
              formatDuration(widget.recordingDuration),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _loadingTexts[_currentTextIndex],
                key: ValueKey<int>(_currentTextIndex),
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}