import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:stt/Screens/about_page.dart';
import 'package:stt/Screens/continuous.dart';
import 'package:stt/Screens/translate.dart';
import 'package:stt/screens/voice_beta.dart';
import 'package:stt/widget/BarIndicator.dart';
import 'package:stt/widget/customappbar.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:iconsax/iconsax.dart';
import 'package:stt/widget/glass.dart';
import 'package:stt/widget/more_options_card_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VoiceApp extends StatefulWidget {
  const VoiceApp({Key? key}) : super(key: key);

  @override
  State<VoiceApp> createState() => _VoiceAppState();
}

class _VoiceAppState extends State<VoiceApp> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Press the mic icon to start';
  double _confidence = 1.0;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _getUserEmail();
  }

  void _getUserEmail() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _userEmail = user?.email;
    });
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontFamily: 'Raleway',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            fontFamily: 'Raleway',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Raleway',
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff006a53),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                fontFamily: 'Raleway',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        if (mounted) {
          Fluttertoast.showToast(
            msg: "✓   Logged out successfully",
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelHeightClosed = MediaQuery.of(context).size.height * 0.3;
    final panelHeightOpen = MediaQuery.of(context).size.height * 0.7;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            MyAppBar(
              title: 'STT Notes',
              onIconTap: _listen,
              iconName: Iconsax.microphone,
            ),
            SlidingUpPanel(
              minHeight: panelHeightClosed,
              maxHeight: panelHeightOpen,
              backdropEnabled: true,
              parallaxEnabled: true,
              color: Colors.transparent,
              panel: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSecondary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BarIndicator(),
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: MediaQuery.of(context).size.width / 4,
                                ),
                                Text(
                                  'Transcribed Text',
                                  style: TextStyle(
                                    fontSize: 24.0,
                                    fontFamily: 'Raleway',
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _copy,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0x28ffffff)),
                                  borderRadius: BorderRadius.circular(16),
                                  color: const Color(0xff272727),
                                ),
                                child: const Icon(
                                  Iconsax.copy,
                                  size: 20,
                                  color: Color(0xa1ffffff),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: TextSelectionTheme(
                          data: const TextSelectionThemeData(
                              selectionColor: Colors.black,
                              selectionHandleColor: Colors.black),
                          child: SelectableText(
                            textAlign: TextAlign.center,
                            _text,
                            style: TextStyle(
                              fontFamily: 'Raleway',
                              fontSize: 24.0,
                              color: Theme.of(context).colorScheme.onBackground,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              collapsed: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSecondary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0),
                  ),
                ),
                child: Column(
                  children: [
                    const BarIndicator(),
                    Center(
                      child: Text(
                        "Swipe Up for more",
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontFamily: 'Raleway'),
                      ),
                    ),
                    const SizedBox(
                      height: 44,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: TextSelectionTheme(
                        data: const TextSelectionThemeData(
                            selectionColor: Colors.black,
                            selectionHandleColor: Colors.black),
                        child: SelectableText(
                          textAlign: TextAlign.center,
                          _text,
                          style: TextStyle(
                            fontFamily: 'Raleway',
                            fontSize: 24.0,
                            color: Theme.of(context).colorScheme.onBackground,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              body: Column(
                children: [
                  const SizedBox(
                    height: 130,
                  ),
                  // User Email Display
                  if (_userEmail != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xff006a53).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xff006a53).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xff006a53),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _userEmail!,
                                style: TextStyle(
                                  fontFamily: 'Raleway',
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onBackground,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _handleLogout,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.logout,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 60,
                    child: ListView(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      children: [
                        OptionsCard(
                          cardTitle: 'Nonstop Mode',
                          iconName: Iconsax.microphone,
                          pageName: const ContinuousVoiceApp(),
                          iconColor: const Color(0xff006a53),
                          darkGradientColor: const Color(0xffd1ffeb),
                          titleColor: const Color(0xff006a53),
                          lightGradientColor: const Color(0xffd1ffeb),
                        ),
                        OptionsCard(
                          cardTitle: 'Translate',
                          iconName: Icons.translate,
                          pageName: const TranslatePage(),
                          iconColor: const Color(0xff006a53),
                          darkGradientColor: const Color(0xffd1ffeb),
                          titleColor: const Color(0xff006a53),
                          lightGradientColor: const Color(0xffd1ffeb),
                        ),
                        OptionsCard(
                          cardTitle: 'Settings',
                          iconName: Icons.person_outline_sharp,
                          pageName: const AboutPage(),
                          iconColor: const Color(0xff006a53),
                          darkGradientColor: const Color(0xffd1ffeb),
                          titleColor: const Color(0xff006a53),
                          lightGradientColor: const Color(0xffd1ffeb),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Glass(listening: _isListening, confidence: _confidence),
                  const Spacer(
                    flex: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));
    Fluttertoast.showToast(
      msg: "✓   Copied to Clipboard",
      toastLength: Toast.LENGTH_SHORT,
    );
  }
}