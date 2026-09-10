import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

// මෙතන ඔයාගේ ඊළඟට යන්න ඕනේ Screen එක Import කරගන්න (Login හෝ Dashboard)
import '../auth/login_screen.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _displayedText = '';
  // මෙන්න මේක තමයි Type වෙන්න ඕනේ වචන ටික
  final String _fullText = 'Powered by OrbitView Innovations\nSystem Loading...\n[|||||||||||||||||||] 100%\nAccess Granted.';
  
  int _charIndex = 0;
  bool _showCursor = true;
  Timer? _typingTimer;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _startTypingEffect();
    _startCursorBlink();
    _navigateToNextScreen();
  }

  // අකුරෙන් අකුර Type වෙන ඇනිමේෂන් එක
  void _startTypingEffect() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_charIndex < _fullText.length) {
        setState(() {
          _displayedText += _fullText[_charIndex];
          _charIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // අගට තියෙන යට ඉර (_) නිවි නිවි පත්තුවෙන එක
  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      setState(() {
        _showCursor = !_showCursor;
      });
    });
  }

  // තත්පර 4කට පස්සේ Main Screen එකට යනවා
  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()), // <--- මෙතනට ඔයාගේ Main Screen එක දෙන්න
      );
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // DOS කළු පසුබිම
      body: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, // වම් පැත්තට බරව
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'C:\\> ', // DOS Command Prompt එක
                      style: GoogleFonts.vt323(color: Colors.greenAccent, fontSize: 26),
                    ),
                    TextSpan(
                      text: _displayedText,
                      style: GoogleFonts.vt323(color: Colors.greenAccent, fontSize: 26),
                    ),
                    TextSpan(
                      text: _showCursor ? '_' : ' ',
                      style: GoogleFonts.vt323(color: Colors.greenAccent, fontSize: 26),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}