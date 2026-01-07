import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/receipt.dart';

class ReceiptDBHelper {
  static final ReceiptDBHelper _instance = ReceiptDBHelper._internal();
  factory ReceiptDBHelper() => _instance;
  static Database? _db;

  ReceiptDBHelper._internal();

  final String tableName = 'receipts';
  final String columnId = 'id';
  final String columnTransactionId = 'transaction_id';
  final String columnImagePath = 'image_path';
  final String columnExtractedText = 'extracted_text';
  final String columnCreatedOn = 'created_on';

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'receipts.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  void _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName(
        $columnId TEXT PRIMARY KEY,
        $columnTransactionId TEXT,
        $columnImagePath TEXT,
        $columnExtractedText TEXT,
        $columnCreatedOn TEXT
      )
    ''');
  }

  Future<int> insertReceipt(Receipt receipt) async {
    var dbClient = await database;
    try {
      return await dbClient.insert(tableName, receipt.toMap());
    } catch (e) {
      return -1;
    }
  }

  Future<Receipt?> getReceiptById(String id) async {
    var dbClient = await database;
    try {
      List<Map<String, dynamic>> maps = await dbClient.query(
        tableName,
        where: '$columnId = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Receipt.fromMap(maps.first);
      }
    } catch (e) {
      // Return null if something goes wrong
    }
    return null;
  }

  Future<Receipt?> getReceiptByTransactionId(String transactionId) async {
    var dbClient = await database;
    try {
      List<Map<String, dynamic>> maps = await dbClient.query(
        tableName,
        where: '$columnTransactionId = ?',
        whereArgs: [transactionId],
      );
      if (maps.isNotEmpty) {
        return Receipt.fromMap(maps.first);
      }
    } catch (e) {
      // Return null if something goes wrong
    }
    return null;
  }

  Future<int> updateReceipt(Receipt receipt) async {
    var dbClient = await database;
    try {
      return await dbClient.update(
        tableName,
        receipt.toMap(),
        where: '$columnId = ?',
        whereArgs: [receipt.id],
      );
    } catch (e) {
      return -1;
    }
  }

  Future<int> deleteReceipt(String id) async {
    var dbClient = await database;
    try {
      // Also delete the image file
      Receipt? receipt = await getReceiptById(id);
      if (receipt != null) {
        File imageFile = File(receipt.imagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      }
      return await dbClient.delete(
        tableName,
        where: '$columnId = ?',
        whereArgs: [id],
      );
    } catch (e) {
      return -1;
    }
  }

  Future<List<Receipt>> getAllReceipts() async {
    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> maps = await dbClient.query(
        tableName,
        orderBy: '$columnCreatedOn DESC',
      );
      return maps.map((map) => Receipt.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> close() async {
    var dbClient = await database;
    try {
      await dbClient.close();
    } catch (e) {
      // Ignore errors on close
    }
  }
}
