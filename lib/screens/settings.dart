import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _userEmail;
  String? _userName;
  String? _userPhotoUrl;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  void _getUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _userEmail = user?.email;
      _userName = user?.displayName ?? 'User';
      _userPhotoUrl = user?.photoURL;
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
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C4B3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                fontFamily: 'Inter',
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
            msg: "Logged out successfully",
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(title: 'Profile', showBack: true,),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  // decoration: BoxDecoration(
                  //   color: Theme.of(context).colorScheme.onSecondary,
                  //   borderRadius: BorderRadius.circular(20),
                  //   boxShadow: [
                  //     BoxShadow(
                  //       color: Colors.black.withOpacity(0.05),
                  //       blurRadius: 10,
                  //       offset: const Offset(0, 4),
                  //     ),
                  //   ],
                  // ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Profile Photo ---
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xff006a53).withOpacity(0.1),
                          border: Border.all(
                            color: const Color(0xff006a53).withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: _userPhotoUrl != null
                            ? ClipOval(
                          child: Image.network(
                            _userPhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: const Color(0xff006a53),
                                ),
                              );
                            },
                          ),
                        )
                            : Center(
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: const Color(0xff006a53),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // --- User Name ---
                      Text(
                        _userName ?? 'User',
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // --- User Email ---
                      Text(
                        _userEmail ?? 'No email',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground
                              .withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // --- Logout Button ---
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(text: 'Log out', onPressed: _handleLogout),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
          )
        ),
      ),
    );
  }
}