import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Terms & Conditions"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            '''
Welcome to our EV Charging Platform.

By using this app as an EV Charging Station Owner, you agree to the following terms:

1. **Accurate Information**: You must provide truthful and up-to-date station details including pricing, connector types, and availability.

2. **Compliance**: All stations must comply with local, regional, and national regulations.

3. **User Conduct**: Treat users with fairness and professionalism. Any misconduct may result in account suspension.

4. **Maintenance**: Ensure your station is regularly maintained, operational, and safe to use.

5. **Platform Rights**: We reserve the right to suspend or terminate your access if any violations of these terms occur.

6. **Updates**: These terms may change over time. Continued use of the platform indicates your acceptance of any updates.

If you do not agree with these terms, please do not proceed with using this platform.

For more information or support, contact our help team at: support@evplatform.com
            ''',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}
