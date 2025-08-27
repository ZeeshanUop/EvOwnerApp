// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:sms_autofill/sms_autofill.dart';
// import '../dashboard.dart';
// import '../utiltiy/AuthLayoutWidget.dart';
//
// class OTPScreen extends StatefulWidget {
//   final String verificationId;
//   final String phoneNumber;
//   final String fullName;
//   final String username;
//   final String email;
//
//   const OTPScreen({
//     super.key,
//     required this.verificationId,
//     required this.phoneNumber,
//     required this.fullName,
//     required this.username,
//     required this.email,
//   });
//
//   @override
//   State<OTPScreen> createState() => _OTPScreenState();
// }
//
// class _OTPScreenState extends State<OTPScreen> with CodeAutoFill {
//   String otpCode = '';
//   bool isLoading = false;
//   int countdown = 60;
//   bool canResend = false;
//   late String _currentVerificationId;
//   Timer? _timer;
//
//   @override
//   void initState() {
//     super.initState();
//     _currentVerificationId = widget.verificationId;
//     listenForCode();
//     _startTimer();
//   }
//
//   void _startTimer() {
//     setState(() {
//       countdown = 60;
//       canResend = false;
//     });
//
//     _timer?.cancel();
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (countdown == 0) {
//         timer.cancel();
//         setState(() => canResend = true);
//       } else {
//         setState(() => countdown--);
//       }
//     });
//   }
//
//   Future<void> _resendOTP() async {
//     await FirebaseAuth.instance.verifyPhoneNumber(
//       phoneNumber: widget.phoneNumber,
//       timeout: const Duration(seconds: 60),
//       verificationCompleted: (PhoneAuthCredential credential) async {
//         await _signInAndSaveData(credential);
//       },
//       verificationFailed: (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Resend failed: ${e.message}")),
//         );
//       },
//       codeSent: (verificationId, _) {
//         setState(() {
//           _currentVerificationId = verificationId;
//         });
//         _startTimer();
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("OTP resent")),
//         );
//       },
//       codeAutoRetrievalTimeout: (verificationId) {
//         _currentVerificationId = verificationId;
//       },
//     );
//   }
//
//   Future<void> verifyOTP() async {
//     if (otpCode.length != 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Enter a valid 6-digit OTP")),
//       );
//       return;
//     }
//
//     setState(() => isLoading = true);
//
//     try {
//       final credential = PhoneAuthProvider.credential(
//         verificationId: _currentVerificationId,
//         smsCode: otpCode,
//       );
//       await _signInAndSaveData(credential);
//     } catch (e) {
//       setState(() => isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Invalid OTP: $e")),
//       );
//     }
//   }
//
//   Future<void> _signInAndSaveData(PhoneAuthCredential credential) async {
//     final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
//     final uid = userCredential.user?.uid;
//
//     if (uid == null) {
//       throw Exception("User ID not found");
//     }
//
//     await FirebaseFirestore.instance.collection('users').doc(uid).set({
//       'uid': uid,
//       'phone': widget.phoneNumber,
//       'name': widget.fullName,
//       'username': widget.username,
//       'email': widget.email,
//       'createdAt': FieldValue.serverTimestamp(),
//     });
//
//     if (mounted) {
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => const Dashboard()),
//             (route) => false,
//       );
//     }
//   }
//
//   @override
//   void codeUpdated() {
//     setState(() {
//       otpCode = code ?? '';
//     });
//     if (otpCode.length == 6) verifyOTP();
//   }
//
//   @override
//   void dispose() {
//     cancel();
//     _timer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AuthFormLayout(
//       title: "OTP Verification",
//       subtitle: "Enter the 6-digit code sent to ${widget.phoneNumber}",
//       image: Image.asset('Assets/Ev3.jpg'),
//       children: [
//         const SizedBox(height: 24),
//         PinFieldAutoFill(
//           currentCode: otpCode,
//           codeLength: 6,
//           decoration: UnderlineDecoration(
//             textStyle: const TextStyle(fontSize: 20, color: Colors.black),
//             colorBuilder: FixedColorBuilder(Colors.green),
//           ),
//           onCodeChanged: (code) {
//             otpCode = code ?? '';
//             if (otpCode.length == 6) verifyOTP();
//           },
//         ),
//         const SizedBox(height: 32),
//         SizedBox(
//           width: double.infinity,
//           height: 50,
//           child: ElevatedButton(
//             onPressed: isLoading ? null : verifyOTP,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green.shade800,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//             ),
//             child: isLoading
//                 ? const CircularProgressIndicator(color: Colors.white)
//                 : const Text('Verify', style: TextStyle(color: Colors.white, fontSize: 16)),
//           ),
//         ),
//         const SizedBox(height: 20),
//         TextButton(
//           onPressed: canResend ? _resendOTP : null,
//           child: Text(canResend ? "Resend code" : "Resend in $countdown s"),
//         ),
//       ],
//     );
//   }
// }
