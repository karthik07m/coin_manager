class Transaction {
  final String id;
  String title;
  double amount;
  int categoryId;
  DateTime date;
  bool isExpense;
  final DateTime createdOn;
  late DateTime modifiedOn;

  Transaction(
      {required this.id,
      required this.title,
      required this.amount,
      required this.categoryId,
      required this.date,
      required this.createdOn,
      required this.modifiedOn,
      required this.isExpense});

  factory Transaction.createNew(
      {required String id,
      required String title,
      required double amount,
      required int categoryId,
      required DateTime date,
      required bool isExpense}) {
    DateTime now = DateTime.now();
    return Transaction(
      id: id,
      title: title,
      amount: amount,
      categoryId: categoryId,
      date: date,
      createdOn: now,
      modifiedOn: now,
      isExpense: isExpense,
    );
  }

  void update(
      {required String title,
      required double amount,
      required int categoryId,
      required bool isExpense}) {
    this.title = title;
    this.amount = amount;
    this.categoryId = categoryId;
    this.isExpense = isExpense;
    modifiedOn = DateTime.now();
  }

  // Convert a Transaction into a Map object
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category_id': categoryId,
      'date': date.toIso8601String(),
      'created_on': createdOn.toIso8601String(),
      'modified_on': modifiedOn.toIso8601String(),
      'is_expense': isExpense ? 1 : 0,
    };
  }

  // Create a Transaction from a Map object
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      categoryId: map['category_id'],
      date: DateTime.parse(map['date']),
      createdOn: DateTime.parse(map['created_on']),
      modifiedOn: DateTime.parse(map['modified_on']),
      isExpense: map['is_expense'] == 1,
    );
  }
}
