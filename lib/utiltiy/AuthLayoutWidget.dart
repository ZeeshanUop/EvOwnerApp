// widgets/auth_form_layout.dart
import 'package:flutter/material.dart';

class AuthFormLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget image;
  final List<Widget> children;

  const AuthFormLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            image,
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 32),
                  ...children,
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
