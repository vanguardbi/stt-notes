import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stt/main.dart';
import 'package:stt/screens/login.dart';

/// This widget listens to authentication state changes
/// and shows LoginScreen or MainPage accordingly
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is logged in, show MainPage
        if (snapshot.hasData && snapshot.data != null) {
          return const MainPage();
        }

        // If user is not logged in, show LoginScreen
        return const LoginScreen();
      },
    );
  }
}