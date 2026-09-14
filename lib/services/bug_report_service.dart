import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class BugReportService {
  static final BugReportService instance = BugReportService._internal();

  BugReportService._internal();

  static const String _supportEmail = 'karthik07m@gmail.com';

  Future<void> sendBugReport() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    String osVersion = '';
    String deviceModel = '';

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      osVersion = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
      deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      deviceModel = iosInfo.utsname.machine;
    }

    final String appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';

    final String body = '''
Please describe the issue you are facing below:

-----------------------------
Diagnostic Info (Please do not edit)
App Version: $appVersion
Device: $deviceModel
OS: $osVersion
-----------------------------
''';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Bug Report: Coinly',
        'body': body,
      },
    );

    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      // Ignore errors if no email client is installed
    }
  }
}
