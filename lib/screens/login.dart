import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:stt/widget/custom_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;

  // Google Sign-In + Firebase Auth
  Future<AuthResponse?> signInWithGoogle() async {
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
      // final credential = GoogleAuthProvider.credential(
      //   accessToken: googleAuth.accessToken,
      //   idToken: googleAuth.idToken,
      // );

      final AuthResponse response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      print('Auth Response: ${response}');

      if (response.user != null) {
        final user = response.user!;

        // We use 'upsert' here. It tries to insert.
        // If there is a conflict (ID already exists), we can tell it to ignore.
        // Or we can just let it update the data (like photoURL) if it changed.

        await Supabase.instance.client.from('users').upsert(
          {
            'id': user.id,
            'email': user.email,
            'display_name': googleUser.displayName, // or user.userMetadata?['full_name']
            'photo_url': googleUser.photoUrl, // or user.userMetadata?['avatar_url']
            // 'created_at': We don't need to send this, Supabase defaults it to now()
          },
          // options: const FetchOptions(duplicateResolution: DuplicateResolution.ignore), // Optional: Keep old data if exists
        );
      }

      setState(() => _isSigningIn = false);
      return response;
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey,
                  backgroundImage: AssetImage('assets/logo/sttlogo.png'),
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
                  child: CustomButton(
                    text: 'Sign in with Google',
                    isLoading: _isSigningIn,
                    onPressed: _isSigningIn
                        ? null
                        : () async {
                      final user = await signInWithGoogle();
                      if (user != null) {
                        // Navigate or show success
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                            Text('Signed in successfully!'),
                          ),
                        );
                        // Navigator.pushReplacementNamed(context, '/home');
                      }
                    }
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
