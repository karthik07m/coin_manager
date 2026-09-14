import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Play Store in-app updates, flexible flow: a newer build downloads in the
/// background while the app stays usable, then the user is offered a restart.
///
/// Android only. iOS has no equivalent API — updates there are handled by the
/// App Store, which is why [UpgradeAlert] still covers that platform.
///
/// Every call is best-effort and swallows failures. The Play API throws
/// whenever it cannot verify the install came from the store — debug builds,
/// sideloads, emulators without Play Services — and none of that is a reason
/// to disturb someone trying to record a transaction.
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  /// Set once a flexible update has finished downloading and is waiting to be
  /// installed. The UI watches this to offer "Restart".
  final ValueNotifier<bool> readyToInstall = ValueNotifier<bool>(false);

  bool _checkInProgress = false;
  bool _downloadStarted = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Looks for a newer build and, if one is available, starts downloading it
  /// in the background. Safe to call on every app start.
  Future<void> checkForUpdate() async {
    if (!_supported || _checkInProgress || _downloadStarted) return;
    _checkInProgress = true;

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      if (info.flexibleUpdateAllowed != true) {
        // The release may be configured to require an immediate update; in
        // that case leave it alone rather than forcing a blocking flow on
        // someone mid-task.
        return;
      }

      _downloadStarted = true;
      await InAppUpdate.startFlexibleUpdate();
      readyToInstall.value = true;
    } catch (e) {
      // Not installed from Play, no Play Services, offline, or the user
      // dismissed the consent sheet. All benign.
      debugPrint('In-app update unavailable: $e');
      _downloadStarted = false;
    } finally {
      _checkInProgress = false;
    }
  }

  /// Installs the downloaded update and restarts the app. Called when the user
  /// accepts the restart prompt.
  Future<void> completeUpdate() async {
    if (!_supported) return;

    try {
      await InAppUpdate.completeFlexibleUpdate();
      readyToInstall.value = false;
    } catch (e) {
      debugPrint('Completing in-app update failed: $e');
    }
  }

  /// Lets the user postpone without being asked again this session.
  void dismiss() {
    readyToInstall.value = false;
  }

  @visibleForTesting
  void resetForTests() {
    _checkInProgress = false;
    _downloadStarted = false;
    readyToInstall.value = false;
  }
}
