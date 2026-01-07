import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import '../db/transaction_db_helper.dart';
import '../models/transaction.dart';

class BackupService {
  final TransactionDBHelper _dbHelper = TransactionDBHelper();

  Future<void> createBackup(BuildContext context) async {
    try {
      // 1. Fetch all transactions
      List<Transaction> transactions = await _dbHelper.getTransactions();

      // 2. Convert to JSON
      List<Map<String, dynamic>> jsonList =
          transactions.map((t) => t.toMap()).toList();
      String jsonString = jsonEncode(jsonList);

      // 3. Save to temporary file
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/coin_manager_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      // 4. Share the file
      await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: 'Coin Manager Backup'));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }

  Future<void> restoreBackup(BuildContext context) async {
    try {
      // 1. Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();

        // 2. Parse JSON
        List<dynamic> jsonList = jsonDecode(jsonString);
        List<Transaction> transactions =
            jsonList.map((map) => Transaction.fromMap(map)).toList();

        // 3. Insert into DB (Optionally clear existing data first, but for safety lets add)
        // Ideally we might want to check for duplicates or clear DB.
        // For this simple implementation, we will append, or update if ID exists.

        int count = 0;
        for (var transaction in transactions) {
          Transaction? existing =
              await _dbHelper.getTransactionById(transaction.id);
          if (existing == null) {
            await _dbHelper.insertTransaction(transaction);
            count++;
          }
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored $count transactions successfully!')),
        );

        // Notify user to refresh or force restart might be needed if state isn't reactive enough globally
        // For better UX, we should likely check if Provider can be reloaded.
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }
}
