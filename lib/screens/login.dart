import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;

  // Google Sign-In + Firebase Auth
  Future<UserCredential?> signInWithGoogle() async {
    try {
      setState(() => _isSigningIn = true);

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isSigningIn = false);
        return null; // User canceled the sign-in
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      setState(() => _isSigningIn = false);
      return userCredential;
    } catch (e) {
      setState(() => _isSigningIn = false);
      debugPrint('Google Sign-In Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $e')),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Profile placeholder
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 20),

                // App name
                const Text(
                  'Speech Therapy Totos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),

                // Google Sign-In button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSigningIn
                        ? null
                        : () async {
                      final user = await signInWithGoogle();
                      if (user != null) {
                        // Navigate or show success
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                            Text('Signed in successfully! 🎉'),
                          ),
                        );
                        // Example: navigate to home
                        // Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSigningIn
                        ? const CircularProgressIndicator(
                      color: Colors.black87,
                    )
                        : const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
