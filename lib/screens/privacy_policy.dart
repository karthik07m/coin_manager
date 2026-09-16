import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Short in-app summary. The published policy is the full, authoritative
/// version (it is what Google reviews for Drive access), so keep the two
/// consistent when either changes.
class PrivacyPolicyScreen extends StatelessWidget {
  static const routeName = '/privacy-policy';
  static final Uri policyUrl =
      Uri.parse('https://karthik07m.github.io/coinly/privacy.html');

  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '''
Privacy Policy

Effective: September 14, 2026

Your data stays on your device
Your transactions, accounts, budgets, debts, goals and receipts are stored on your phone. We do not keep a copy on our servers. Coinly has no ads and no analytics.

AI assistant (optional)
Many messages are understood on your device. When a message needs cloud processing, Coinly sends the text you typed, your currency and time zone, and your category and account names to a function hosted on Supabase, which uses Anthropic (Claude) to prepare a draft. Your transaction history and balances are not sent. The app signs in anonymously so it can apply a monthly limit on AI requests. You can turn the AI assistant off in Settings.

Google Drive backup (optional)
If you connect Google Drive, Coinly can only see the backup files it creates in your Drive. Backups go to your own Drive, not to us. You can disconnect at any time.

Receipts, voice and app lock
Receipt text is read on your device. Voice input uses your phone's speech service. Biometric unlock is handled by your device.

Contact
karthik07m@gmail.com
''',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                policyUrl,
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Read the full privacy policy'),
            ),
          ],
        ),
      ),
    );
  }
}
