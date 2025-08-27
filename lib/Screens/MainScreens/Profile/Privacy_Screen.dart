import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Privacy Policy\n\n'
              '1. We collect user data for booking and personalization.\n'
              '2. We do not share your personal data with third parties.\n'
              '3. You can update or delete your profile anytime.\n'
              '4. Your data is stored securely on Firebase.\n\n'
              'By using this app, you agree to this privacy policy.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
