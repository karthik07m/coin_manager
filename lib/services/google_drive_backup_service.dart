import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'backup_service.dart';

/// A single backup file stored on the user's Google Drive.
class DriveBackup {
  final String id;
  final String name;
  final DateTime? modified;
  final int? sizeBytes;
  DriveBackup(
      {required this.id, required this.name, this.modified, this.sizeBytes});
}

/// Backs up / restores the app's data ZIP to the user's own Google Drive.
///
/// Uses the `drive.file` scope, so the app can ONLY see files it created —
/// it can never read the rest of the user's Drive. Requires a Google Cloud
/// OAuth setup (consent screen + the app's SHA-1) to authenticate on-device;
/// see the in-app note if sign-in fails.
class GoogleDriveBackupService {
  static final GoogleDriveBackupService _instance =
      GoogleDriveBackupService._internal();
  factory GoogleDriveBackupService() => _instance;
  GoogleDriveBackupService._internal();

  static const String _backupPrefix = 'coinly_backup_';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[drive.DriveApi.driveFileScope],
  );

  final BackupService _backupService = BackupService();

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  String? get accountEmail => _googleSignIn.currentUser?.email;

  /// Try to restore a previous session silently (no UI).
  Future<String?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      return account?.email;
    } catch (e) {
      debugPrint('Drive signInSilently failed: $e');
      return null;
    }
  }

  /// Interactive sign-in. Returns the account email, or null if cancelled.
  Future<String?> signIn() async {
    final account = await _googleSignIn.signIn();
    return account?.email;
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<drive.DriveApi> _driveApi() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception('Not signed in to Google.');
    }
    return drive.DriveApi(client);
  }

  /// Creates a fresh local backup ZIP and uploads it to Drive.
  /// Returns the uploaded file's name.
  Future<String> uploadBackup() async {
    // Ensure we have a session (interactive if needed).
    if (_googleSignIn.currentUser == null) {
      final email = await signIn();
      if (email == null) throw Exception('Google sign-in was cancelled.');
    }

    final api = await _driveApi();
    final localZipPath = await _backupService.createBackup();
    final file = File(localZipPath);
    final length = await file.length();

    final driveFile = drive.File()
      ..name = '$_backupPrefix${_stamp()}.zip'
      ..mimeType = 'application/zip'
      // Marker so we can recognise our own backups.
      ..appProperties = {'app': 'coinly', 'kind': 'backup'};

    final media = drive.Media(file.openRead(), length);
    final created = await api.files.create(driveFile, uploadMedia: media);

    // Clean up the local temp zip we just uploaded.
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}

    return created.name ?? driveFile.name!;
  }

  /// Lists this app's backups on Drive, newest first.
  Future<List<DriveBackup>> listBackups() async {
    final api = await _driveApi();
    final result = await api.files.list(
      q: "trashed = false and name contains '$_backupPrefix'",
      orderBy: 'modifiedTime desc',
      $fields: 'files(id, name, modifiedTime, size)',
      spaces: 'drive',
    );
    final files = result.files ?? const <drive.File>[];
    return files
        .where((f) => f.id != null)
        .map((f) => DriveBackup(
              id: f.id!,
              name: f.name ?? 'backup.zip',
              modified: f.modifiedTime,
              sizeBytes: int.tryParse(f.size ?? ''),
            ))
        .toList();
  }

  /// Downloads the given Drive backup and restores it into the app.
  Future<void> downloadAndRestore(String fileId) async {
    final api = await _driveApi();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        p.join(tempDir.path, 'drive_restore_${DateTime.now().millisecondsSinceEpoch}.zip');
    final out = File(outPath);
    final sink = out.openWrite();
    await media.stream.pipe(sink);
    await sink.flush();
    await sink.close();

    try {
      await _backupService.restoreBackup(outPath);
    } finally {
      try {
        if (await out.exists()) await out.delete();
      } catch (_) {}
    }
  }

  Future<void> deleteBackup(String fileId) async {
    final api = await _driveApi();
    await api.files.delete(fileId);
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
