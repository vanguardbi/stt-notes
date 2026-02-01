import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:stt/widget/auth_wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stt/widget/custom_appbar.dart';
import 'package:stt/widget/custom_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;

  String? _userEmail;
  String? _userName;
  String? _userAvatar;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() {
    final user = supabase.auth.currentUser;

    setState(() {
      _userEmail = user?.email;
      _userName = user?.userMetadata?['full_name'] ?? "User";
      _userAvatar = user?.userMetadata?['avatar_url'];
    });
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
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
              "Logout",
              style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
            ),),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      await supabase.auth.signOut();
      await GoogleSignIn().signOut();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error logging out: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: const CustomAppBar(title: 'Profile', showBack: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),

            CircleAvatar(
              radius: 50,
              backgroundImage:
              _userAvatar != null ? NetworkImage(_userAvatar!) : null,
              child: _userAvatar == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 16),

            Text(
              _userName ?? "User",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Text(
              _userEmail ?? "Email not available",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: CustomButton(text: "Log out", onPressed: _logout),
            )
          ],
        ),
      ),
    );
  }
}
