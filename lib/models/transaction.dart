class Transaction {
  final String id;
  String title;
  double amount;
  int categoryId;
  int accountId;
  DateTime date;
  bool isExpense;
  bool isRecurring;
  String? receiptId;
  final DateTime createdOn;
  late DateTime modifiedOn;

  Transaction(
      {required this.id,
      required this.title,
      required this.amount,
      required this.categoryId,
      required this.accountId,
      required this.date,
      required this.createdOn,
      required this.modifiedOn,
      required this.isExpense,
      this.isRecurring = false,
      this.receiptId});

  factory Transaction.createNew(
      {required String id,
      required String title,
      required double amount,
      required int categoryId,
      required int accountId,
      required DateTime date,
      required bool isExpense,
      bool isRecurring = false,
      String? receiptId}) {
    DateTime now = DateTime.now();
    return Transaction(
      id: id,
      title: title,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      date: date,
      createdOn: now,
      modifiedOn: now,
      isExpense: isExpense,
      isRecurring: isRecurring,
      receiptId: receiptId,
    );
  }

  void update(
      {required String title,
      required double amount,
      required int categoryId,
      required int accountId,
      required bool isExpense,
      required bool isRecurring}) {
    this.title = title;
    this.amount = amount;
    this.categoryId = categoryId;
    this.accountId = accountId;
    this.isExpense = isExpense;
    this.isRecurring = isRecurring;
    modifiedOn = DateTime.now();
  }

  // Convert a Transaction into a Map object
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category_id': categoryId,
      'account_id': accountId,
      'date': date.toIso8601String(),
      'created_on': createdOn.toIso8601String(),
      'modified_on': modifiedOn.toIso8601String(),
      'is_expense': isExpense ? 1 : 0,
      'is_recurring': isRecurring ? 1 : 0,
      'receipt_id': receiptId,
    };
  }

  // Create a Transaction from a Map object
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      categoryId: map['category_id'],
      accountId: map['account_id'] ?? 1, // Default to first account if missing
      date: DateTime.parse(map['date']),
      createdOn: DateTime.parse(map['created_on']),
      modifiedOn: DateTime.parse(map['modified_on']),
      isExpense: map['is_expense'] == 1,
      isRecurring: map['is_recurring'] == 1,
      receiptId: map['receipt_id'],
    );
  }
}
