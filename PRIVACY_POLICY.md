# Privacy Policy for Coinly

**Effective Date: September 14, 2026**

The published version of this policy is at https://karthik07m.github.io/privacy.html and is the one that applies. This file mirrors it.

This Privacy Policy explains how the Coinly mobile app ("Coinly", "the App", "we", "us") handles your information, including information received from Google APIs.

## 1. Summary
- Your financial records are stored on your device. We do not run our own database of your transactions.
- Coinly has no ads, no analytics and no crash-reporting services.
- Data leaves your device only when you use an optional cloud feature: the AI assistant or Google Drive backup.
- We never sell your data.

## 2. Data Stored on Your Device
Transactions, accounts, balances, categories, budgets, debts, goals, recurring payments, receipt images and settings are stored locally in the App's private storage and are not uploaded to us. Uninstalling the App deletes them unless you have made a backup.

Receipt scanning reads text from photos using Google ML Kit on your device. Voice input uses your phone's built-in speech recognition service, under your operating system's privacy terms.

## 3. Google User Data (Google Sign-In and Google Drive)
Google Drive backup is optional. If you turn it on, Coinly requests:
- **Basic account information** (email address and name), used only to show which Google account is connected.
- **Google Drive access limited to files Coinly creates** (`drive.file` scope). Coinly cannot see, read or change any other files in your Drive.

Coinly uses this access only to upload backups you request, list them, download one when you restore, and remove old Coinly backups. A backup is a ZIP of your Coinly data and receipt images saved to your own Google Drive. We do not receive, store or share your Google account information or backup contents, and we do not use Google user data for advertising or AI training. You can disconnect Drive in the App and revoke access at https://myaccount.google.com/permissions.

Coinly's use and transfer of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

## 4. AI Assistant
Many messages are understood on your device. When a message needs cloud processing and the AI assistant is enabled, the App sends:
- The text you typed or spoke (which may include amounts, e.g. "coffee 150")
- Your currency, language setting, time zone and current local time
- The names of your categories and accounts

Your transaction history and account balances are not sent. Requests go to a function hosted on Supabase, which forwards them to Anthropic (Claude). Nothing is saved until you confirm it in the App.

To apply a monthly limit, the App creates an anonymous Supabase account on first cloud AI use. It is not linked to your name, email or Google account; we store that anonymous ID with a monthly request count. Supabase may keep standard service logs such as IP addresses. You can turn off the AI assistant in Settings.

## 5. Other Services
- **Google Play**: update checks and in-app reviews.
- **Notifications and App Lock**: reminders are scheduled on your device; biometric unlock is handled by your device.
- **Report a Bug**: prepares an email with basic device and app version details, sent only if you send it.

## 6. Security
Data sent to cloud features is encrypted in transit using HTTPS. On-device data is protected by your device's security and Coinly's optional App Lock.

## 7. Your Choices and Deletion
You can use Coinly without cloud features, delete on-device data by clearing app data or uninstalling, delete Drive backups from Google Drive, and request deletion of your anonymous AI usage record by emailing karthik07m@gmail.com.

## 8. Children
Coinly is not directed to children under 13, and we do not knowingly collect their personal information.

## 9. Changes
We may update this policy and will post changes with a new effective date.

## 10. Contact Us
karthik07m@gmail.com
