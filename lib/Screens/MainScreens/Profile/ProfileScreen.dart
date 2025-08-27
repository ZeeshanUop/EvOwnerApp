import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Booking/Booking_History.dart';
import '../../SplashScreens/splash_screen.dart';
import 'EditProfileScreen.dart';
import '../Notifications/NotificationScreen.dart';
import 'Help_And_Support_Screen.dart';
import 'Faq_Screen.dart';
import 'Privacy_Screen.dart';
import 'Terms_And_Condition.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    final uid = user.uid;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data == null || snapshot.data!.data() == null) {
              return const Center(child: Text("No profile data found."));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final name = data['name'] ?? data['fullName'] ?? 'No Name';
            final phone = data['phone'] ?? 'No Phone';
            final photoURL = data['photoURL'];

            return Column(
              children: [
                _buildProfileHeader(photoURL, name, phone, isDark),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    children: [
                      const SizedBox(height: 8),
                      _buildSectionTitle("Account", isDark),
                      _buildTile(context, Icons.edit, "Edit Profile", () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                      }, isDark),
                      _buildTile(context, Icons.calendar_today, "My Bookings", () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingScreen()));
                      }, isDark),
                      _buildTile(context, Icons.notifications, "Notifications", () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                      }, isDark),

                      const SizedBox(height: 20),
                      _buildSectionTitle("Support", isDark),
                      _buildTile(context, Icons.view_compact_outlined, "Terms and Conditions", () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => TermsAndConditionsScreen()));
                      }, isDark),
                      _buildTile(context, Icons.toc, "FAQ", () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FaqScreen()));
                      }, isDark),
                      _buildTile(context, Icons.privacy_tip_outlined, "Privacy Policy", () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyPolicyScreen()));
                      }, isDark),
                      _buildTile(context, Icons.help_outline, "Help & Support", () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => HelpSupportScreen()));
                      }, isDark),

                      const SizedBox(height: 30),
                      _buildLogoutTile(context, isDark),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 🔹 Profile Header with Gradient & Shadow
  Widget _buildProfileHeader(String? photoURL, String name, String phone, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [Colors.grey.shade900, Colors.grey.shade800] : [Colors.teal.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: photoURL != null
                ? NetworkImage(photoURL)
                : const AssetImage('assets/images/profile.jpg') as ImageProvider,
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            phone.isNotEmpty ? phone : 'Phone number not set',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// 🔹 Section Title (e.g. "Account", "Support")
  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  /// 🔹 Beautiful List Tiles
  Widget _buildTile(BuildContext context, IconData icon, String title, VoidCallback onTap, bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: isDark ? Colors.grey[850] : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: isDark ? Colors.teal.withOpacity(0.2) : Colors.teal.withOpacity(0.1),
          child: Icon(icon, color: isDark ? Colors.tealAccent : Colors.teal),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white54 : Colors.black45),
        onTap: onTap,
      ),
    );
  }

  /// 🔹 Logout Button with Red Highlight
  Widget _buildLogoutTile(BuildContext context, bool isDark) {
    return Card(
      color: isDark ? Colors.red.withOpacity(0.08) : Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFE5E5),
          child: Icon(Icons.logout, color: Colors.red),
        ),
        title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Confirm Logout", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              content: Text("Are you sure you want to log out?",
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Logout", style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => SplashScreen()),
                          (route) => false,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
