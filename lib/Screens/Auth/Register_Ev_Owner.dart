import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool isTermsAccepted = false;

  void _registerUser() async {
    if (!_formKey.currentState!.validate() || !isTermsAccepted) return;

    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    final fullName = fullNameController.text.trim();
    final username = usernameController.text.trim();

    setState(() => isLoading = true);

    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email is already in use")),
        );
        return;
      }

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': fullName,
        'username': username,
        'email': email,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔐 Send email verification
      await userCredential.user!.sendEmailVerification();

      // 🚪 Sign out user
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Verify Your Email"),
            content: const Text(
              "A verification email has been sent to your email address. "
                  "Please verify your email before logging in.",
            ),
            actions: [
              TextButton(
                child: const Text("Go to Login"),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, "/SignIn"); // Change as per your login route
                },
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: ${e.message}")),
      );
    }
  }


  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Terms and Conditions"),
        content: const SingleChildScrollView(
          child: Text(
            "By registering as an EV Charging Station Owner on our platform, you agree to provide accurate information, maintain your station, comply with all applicable laws, and treat users respectfully. We reserve the right to suspend your account for any violations. Continued use implies acceptance of updates to these terms.",
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('Assets/Ev4.jpg', height: 220, width: double.infinity, fit: BoxFit.cover),
              const SizedBox(height: 16),
              const Text("Register", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("Create your EV Owner account", style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 20),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: fullNameController,
                      decoration: _inputDecoration("Full Name"),
                      validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: usernameController,
                      decoration: _inputDecoration("Username"),
                      validator: (value) => value == null || value.isEmpty ? 'Enter a username' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: emailController,
                      decoration: _inputDecoration("Email Address"),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                      value != null && value.contains('@') ? null : 'Enter valid email',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      decoration: _inputDecoration("Phone Number"),
                      validator: (value) =>
                      value != phoneController.text ? 'Phone number' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: passwordController,
                      decoration: _inputDecoration("Password").copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      obscureText: !_showPassword,
                      validator: (value) =>
                      value != null && value.length >= 6 ? null : 'Min 6 characters',
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: _inputDecoration("Confirm Password").copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_showConfirmPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                        ),
                      ),
                      obscureText: !_showConfirmPassword,
                      validator: (value) =>
                      value != passwordController.text ? 'Passwords do not match' : null,
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Checkbox(
                          value: isTermsAccepted,
                          onChanged: (value) => setState(() => isTermsAccepted = value ?? false),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showTermsDialog,
                            child: const Text.rich(
                              TextSpan(
                                text: "I agree to the ",
                                children: [
                                  TextSpan(
                                    text: "Terms and Conditions",
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading || !isTermsAccepted ? null : _registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Register", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
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


  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.grey.shade100,
    );
  }
}
