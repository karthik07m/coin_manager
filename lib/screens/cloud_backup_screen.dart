import 'package:flutter/material.dart';
import '../services/google_drive_backup_service.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

/// Back up / restore the app's data to the user's own Google Drive.
class CloudBackupScreen extends StatefulWidget {
  static const routeName = '/cloud-backup';

  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  final GoogleDriveBackupService _drive = GoogleDriveBackupService();

  String? _email;
  bool _busy = false;
  String _busyLabel = '';
  List<DriveBackup> _backups = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() => _busy = true);
    final email = await _drive.signInSilently();
    if (!mounted) return;
    setState(() {
      _email = email;
      _busy = false;
    });
    if (email != null) _refreshList();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _busyLabel = label;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = '';
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('ApiException: 10') ||
        s.toLowerCase().contains('developer') ||
        s.contains('12500') ||
        s.contains('sign_in_failed')) {
      return 'Google sign-in failed. This usually means the app isn\'t yet '
          'registered in a Google Cloud project (OAuth consent screen + this '
          'app\'s SHA-1 + Drive API enabled). See setup below.';
    }
    return s.replaceFirst('Exception: ', '');
  }

  Future<void> _signIn() =>
      _run('Signing in…', () async {
        final email = await _drive.signIn();
        setState(() => _email = email);
        if (email != null) await _loadBackups();
      });

  Future<void> _signOut() =>
      _run('Signing out…', () async {
        await _drive.signOut();
        setState(() {
          _email = null;
          _backups = [];
        });
      });

  Future<void> _backupNow() => _run('Backing up…', () async {
        final name = await _drive.uploadBackup();
        setState(() => _email = _drive.accountEmail);
        await _loadBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backed up to Drive: $name')),
          );
        }
      });

  Future<void> _refreshList() => _run('Loading backups…', _loadBackups);

  Future<void> _loadBackups() async {
    final list = await _drive.listBackups();
    if (mounted) setState(() => _backups = list);
  }

  Future<void> _restore(DriveBackup b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Text('Restore this backup?', style: AppTextStyles.h3),
        content: Text(
          'This replaces your current data with the contents of "${b.name}". '
          'A safety backup of your current data is made first.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: context.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Restore',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: context.appAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run('Restoring…', () async {
      await _drive.downloadAndRestore(b.id);
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.appSurface,
            title: Text('Restore complete', style: AppTextStyles.h3),
            content: Text(
              'Your data was restored. Please fully close and reopen the app '
              'so everything reloads.',
              style: AppTextStyles.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: context.appAccent)),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _delete(DriveBackup b) async {
    await _run('Deleting…', () async {
      await _drive.deleteBackup(b.id);
      await _loadBackups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Google Drive Backup'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            children: [
              _accountCard(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _errorCard(),
              ],
              const SizedBox(height: 20),
              if (_email != null) ...[
                Text('Backups on Drive',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_backups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('No backups yet. Tap "Back up now".',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: context.textSecondary)),
                  )
                else
                  ..._backups.map(_backupTile),
              ],
              const SizedBox(height: 28),
              _setupNote(),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(_busyLabel,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _email == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _backupNow,
              backgroundColor: context.appAccent,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Back up now'),
            ),
    );
  }

  Widget _accountCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_outlined, color: context.appAccent, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _email == null ? 'Not connected' : 'Connected',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _email ?? 'Sign in to back up to your Google Drive',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : (_email == null ? _signIn : _signOut),
            child: Text(_email == null ? 'Sign in' : 'Sign out'),
          ),
        ],
      ),
    );
  }

  Widget _backupTile(DriveBackup b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: context.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_zip_outlined, color: context.appAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (b.modified != null)
                  Text(
                    '${b.modified!.toLocal()}'.split('.').first,
                    style: AppTextStyles.caption
                        .copyWith(color: context.textSecondary),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Restore',
            icon: Icon(Icons.restore, color: context.appAccent),
            onPressed: _busy ? null : () => _restore(b),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline, color: AppColors.negative),
            onPressed: _busy ? null : () => _delete(b),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.negative.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.negative.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: AppColors.negative, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _setupNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: context.textSecondary),
              const SizedBox(width: 8),
              Text('One-time setup',
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Google sign-in needs this app registered in a Google Cloud '
            'project: create an OAuth consent screen, enable the Drive API, '
            'and add an Android OAuth client with this app\'s package name and '
            'signing SHA-1. Only the drive.file scope is used, so the app can '
            'only ever see backups it created — never the rest of your Drive.',
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
