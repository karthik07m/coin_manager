import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/transaction_db_helper.dart';
import '../db/category_db_helper.dart';
import '../db/monthly_budget_db_helper.dart';
import '../db/receipt_db_helper.dart';
import '../db/debt_db_helper.dart';
import '../models/backup_data.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  /// Creates a backup and returns the file path
  Future<String> createBackup({String? customName}) async {
    try {
      // 1. Collect all data
      final backupData = await _collectAllData();

      // 2. Create temp directory for backup
      final tempDir = await getTemporaryDirectory();
      final backupTempDir = Directory(path.join(tempDir.path, 'backup_temp'));
      if (await backupTempDir.exists()) {
        await backupTempDir.delete(recursive: true);
      }
      await backupTempDir.create();

      // 3. Write JSON data
      final jsonFile = File(path.join(backupTempDir.path, 'backup.json'));
      await jsonFile.writeAsString(jsonEncode(backupData.toJson()));

      // 4. Copy receipt images
      final receiptsDir = Directory(path.join(backupTempDir.path, 'receipts'));
      await receiptsDir.create();
      await _copyReceiptImages(backupData.receipts, receiptsDir);

      // 5. Create ZIP archive
      final backupName =
          customName ?? 'coinmanager_backup_${_formatDateTime(DateTime.now())}';
      final zipPath = await _createZipArchive(backupTempDir, backupName);

      // 6. Cleanup temp directory
      await backupTempDir.delete(recursive: true);

      return zipPath;
    } catch (e) {
      throw Exception('Failed to create backup: $e');
    }
  }

  /// Shares the backup file
  Future<void> shareBackup(String backupPath) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(backupPath)],
          text:
              'Coin Manager Backup - ${DateTime.now().toString().substring(0, 10)}',
        ),
      );
    } catch (e) {
      throw Exception('Failed to share backup: $e');
    }
  }

  /// Restores data from a backup file
  Future<void> restoreBackup(String backupPath) async {
    try {
      // 1. Create safety backup before restore
      await createBackup(
          customName: 'pre_restore_backup_${_formatDateTime(DateTime.now())}');

      // 2. Extract ZIP archive
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory(path.join(tempDir.path, 'restore_temp'));
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create();

      await _extractZipArchive(backupPath, extractDir);

      // 3. Read and validate JSON
      final jsonFile = File(path.join(extractDir.path, 'backup.json'));
      if (!await jsonFile.exists()) {
        throw Exception('Invalid backup file: missing backup.json');
      }

      final jsonString = await jsonFile.readAsString();
      final backupData = BackupData.fromJson(jsonDecode(jsonString));

      // 4. Clear existing databases
      await _clearAllDatabases();

      // 5. Restore data in correct order
      await _restoreCategories(backupData.categories);
      await _restoreBudgetValues(backupData.budgetValues);
      await _restoreBudgetTotals(backupData.budgetTotals);
      await _restoreTransactions(backupData.transactions);
      await _restoreReceipts(backupData.receipts);
      await _restoreDebts(backupData.debts);
      await _restoreDebtPayments(backupData.debtPayments);
      await _restoreAccounts(backupData.accounts);
      await _restoreSettings(backupData.settings);

      // 6. Restore receipt images
      final receiptsDir = Directory(path.join(extractDir.path, 'receipts'));
      if (await receiptsDir.exists()) {
        await _restoreReceiptImages(receiptsDir);
      }

      // 7. Cleanup
      await extractDir.delete(recursive: true);
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }

  // ==================== Private Helper Methods ====================

  Future<BackupData> _collectAllData() async {
    // Get all transactions
    final transactionDb = TransactionDBHelper();
    final transactionsDb = await transactionDb.database;
    final transactions = await transactionsDb.query('transactions');

    // Get all categories
    final categoryDb = DBHelper();
    final categories = await categoryDb.getAllCategories();

    // Get all budget values
    final budgetDb = MonthlyBudgetDBHelper();
    final budgetDatabase = await budgetDb.database;
    final budgetValues = await budgetDatabase.query('budget_values');
    final budgetTotals = await budgetDatabase.query('budget_totals');

    // Get all receipts
    final receiptDb = ReceiptDBHelper();
    final receipts = await receiptDb.getAllReceipts();
    final receiptsData = receipts.map((r) => r.toMap()).toList();

    // Get all debts
    final debtDb = DebtDBHelper();
    final debtsDatabase = await debtDb.database;
    final debts = await debtsDatabase.query('debts');
    final debtPayments = await debtsDatabase.query('debt_payments');

    // Get all accounts
    final accounts = await transactionsDb.query('accounts');

    // Get all settings from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{};
    final keys = prefs.getKeys();
    for (String key in keys) {
      settings[key] = prefs.get(key);
    }

    return BackupData(
      version: BackupData.currentVersion,
      createdAt: DateTime.now(),
      transactions: transactions,
      categories: categories,
      budgetValues: budgetValues,
      budgetTotals: budgetTotals,
      receipts: receiptsData,
      debts: debts,
      debtPayments: debtPayments,
      accounts: accounts,
      settings: settings,
    );
  }

  Future<void> _copyReceiptImages(
      List<Map<String, dynamic>> receipts, Directory targetDir) async {
    for (final receipt in receipts) {
      final imagePath = receipt['image_path'] as String?;
      if (imagePath != null) {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) {
          final targetFile = File(path.join(
            targetDir.path,
            path.basename(imagePath),
          ));
          await imageFile.copy(targetFile.path);
        }
      }
    }
  }

  Future<String> _createZipArchive(
      Directory sourceDir, String backupName) async {
    final encoder = ZipEncoder();
    final archive = Archive();

    // Add all files from source directory
    await for (final entity
        in sourceDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: sourceDir.path);
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }

    // Encode to ZIP
    final zipBytes = encoder.encode(archive);

    // Save to app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(path.join(appDir.path, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    final zipFile = File(path.join(backupsDir.path, '$backupName.zip'));
    await zipFile.writeAsBytes(zipBytes!);

    return zipFile.path;
  }

  Future<void> _extractZipArchive(String zipPath, Directory targetDir) async {
    final zipFile = File(zipPath);
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = path.join(targetDir.path, file.name);
      if (file.isFile) {
        final outFile = File(filename);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filename).create(recursive: true);
      }
    }
  }

  Future<void> _clearAllDatabases() async {
    // Clear transactions
    final transactionDb = await TransactionDBHelper().database;
    await transactionDb.delete('transactions');

    // Clear categories (except default ones - we'll re-insert)
    final categoryDb = await DBHelper().database;
    await categoryDb.delete('categories');

    // Clear budgets
    final budgetDb = await MonthlyBudgetDBHelper().database;
    await budgetDb.delete('budget_values');
    await budgetDb.delete('budget_totals');

    // Clear receipts
    final receiptDb = await ReceiptDBHelper().database;
    await receiptDb.delete('receipts');

    // Clear debts and payments
    final debtDb = await DebtDBHelper().database;
    await debtDb.delete('debt_payments');
    await debtDb.delete('debts');

    // Clear accounts
    await transactionDb.delete('accounts');
  }

  Future<void> _restoreCategories(List<Map<String, dynamic>> categories) async {
    final db = await DBHelper().database;
    final batch = db.batch();
    for (final category in categories) {
      batch.insert('categories', category,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _restoreBudgetValues(
      List<Map<String, dynamic>> budgetValues) async {
    final db = await MonthlyBudgetDBHelper().database;
    final batch = db.batch();
    for (final budgetValue in budgetValues) {
      batch.insert('budget_values', budgetValue,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _restoreBudgetTotals(
      List<Map<String, dynamic>> budgetTotals) async {
    final db = await MonthlyBudgetDBHelper().database;
    final batch = db.batch();
    for (final budgetTotal in budgetTotals) {
      batch.insert('budget_totals', budgetTotal,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _restoreTransactions(
      List<Map<String, dynamic>> transactions) async {
    final db = await TransactionDBHelper().database;
    final batch = db.batch();
    for (final transaction in transactions) {
      batch.insert('transactions', transaction,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _restoreReceipts(List<Map<String, dynamic>> receipts) async {
    final db = await ReceiptDBHelper().database;
    final batch = db.batch();
    for (final receipt in receipts) {
      batch.insert('receipts', receipt,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _restoreDebts(List<Map<String, dynamic>> debts) async {
    final db = await DebtDBHelper().database;
    final batch = db.batch();
    for (final debt in debts) {
      batch.insert('debts', debt, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _restoreDebtPayments(
      List<Map<String, dynamic>> debtPayments) async {
    final db = await DebtDBHelper().database;
    final batch = db.batch();
    for (final payment in debtPayments) {
      batch.insert('debt_payments', payment,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _restoreAccounts(List<Map<String, dynamic>> accounts) async {
    final db = await TransactionDBHelper().database;
    final batch = db.batch();
    for (final account in accounts) {
      batch.insert('accounts', account,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _restoreSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in settings.keys) {
      final value = settings[key];
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.map((e) => e.toString()).toList());
      }
    }
  }

  Future<void> _restoreReceiptImages(Directory sourceDir) async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(path.join(appDir.path, 'receipts'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    await for (final entity in sourceDir.list()) {
      if (entity is File) {
        final targetFile =
            File(path.join(receiptsDir.path, path.basename(entity.path)));
        await entity.copy(targetFile.path);
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}_${dateTime.hour.toString().padLeft(2, '0')}${dateTime.minute.toString().padLeft(2, '0')}${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// Gets list of available backups
  Future<List<BackupInfo>> getAvailableBackups() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupsDir = Directory(path.join(appDir.path, 'backups'));

      if (!await backupsDir.exists()) {
        return [];
      }

      final backups = <BackupInfo>[];
      await for (final entity in backupsDir.list()) {
        if (entity is File && entity.path.endsWith('.zip')) {
          final stat = await entity.stat();
          backups.add(BackupInfo(
            name: path.basenameWithoutExtension(entity.path),
            path: entity.path,
            createdAt: stat.modified,
            sizeBytes: stat.size,
          ));
        }
      }

      // Sort by creation date (newest first)
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return backups;
    } catch (e) {
      return [];
    }
  }

  /// Deletes a backup file
  Future<void> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete backup: $e');
    }
  }
}
