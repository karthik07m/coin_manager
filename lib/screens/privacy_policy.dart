import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  static const routeName = '/privacy-policy';
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: const Text(
          '''
Privacy Policy

Last Updated: January 4, 2026

1. Introduction
Welcome to Coin Manager. We are committed to protecting your personal information and your right to privacy.

2. Data Collection
We do not collect any personal information. All your data, including transactions and categories, is stored locally on your device.

3. Data Storage
Your data is stored securely on your device. We do not transmit your data to any external servers.

4. Categories & Budget
Your category and budget preferences are stored locally to enhance your experience.

5. Changes to This Policy
We may update this privacy policy from time to time. The updated version will be indicated by an updated "Revised" date.

6. Contact Us
If you have questions or comments about this policy, please contact us.
          ''',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
