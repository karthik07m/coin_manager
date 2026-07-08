import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether this device has biometrics enrolled or a device
  /// passcode/PIN/pattern set up, so app lock has something to check against.
  Future<bool> isAvailable() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user with biometrics, falling back to device
  /// PIN/pattern/password. Returns false (never throws) on any failure.
  Future<bool> authenticate({String reason = 'Unlock Coinly'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
