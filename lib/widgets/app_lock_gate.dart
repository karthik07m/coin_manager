import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_lock_service.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

/// Wraps the app and shows a lock screen requiring biometric/PIN
/// authentication on cold start and whenever the app returns from
/// the background, when App Lock is enabled in Settings.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.isAppLockEnabled) {
      _isLocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _attemptUnlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.isAppLockEnabled) return;

    // Only react to a real backgrounding, not the transient `inactive`
    // state (which also fires for the biometric prompt itself, share
    // sheets, incoming calls, etc.) — reacting to it would cause the
    // app to immediately re-lock itself while showing the unlock prompt.
    if (state == AppLifecycleState.paused) {
      if (!_isLocked) {
        setState(() => _isLocked = true);
      }
    } else if (state == AppLifecycleState.resumed && _isLocked) {
      _attemptUnlock();
    }
  }

  Future<void> _attemptUnlock() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    final success = await AppLockService().authenticate();
    _isAuthenticating = false;
    if (!mounted) return;
    if (success) {
      setState(() => _isLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        if (!settings.isAppLockEnabled) {
          return widget.child;
        }
        return Stack(
          children: [
            widget.child,
            if (_isLocked)
              _LockScreen(
                isAuthenticating: _isAuthenticating,
                onUnlockTap: _attemptUnlock,
              ),
          ],
        );
      },
    );
  }
}

class _LockScreen extends StatelessWidget {
  final bool isAuthenticating;
  final VoidCallback onUnlockTap;

  const _LockScreen({
    required this.isAuthenticating,
    required this.onUnlockTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appBackground,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: context.appAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 40,
                    color: context.appAccent,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing24),
                Text(
                  'Coinly is Locked',
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                Text(
                  'Authenticate to view your financial data',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacing32),
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: isAuthenticating ? null : onUnlockTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appAccent,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                    ),
                    icon: isAuthenticating
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.onPrimary),
                            ),
                          )
                        : const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      isAuthenticating ? 'Authenticating...' : 'Unlock',
                      style: AppTextStyles.button,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
