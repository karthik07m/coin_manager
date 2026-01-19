class DebtPayment {
  final String id;
  final String debtId;
  double amount;
  DateTime paymentDate;
  String? notes;
  final DateTime createdOn;

  DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paymentDate,
    this.notes,
    required this.createdOn,
  });

  factory DebtPayment.createNew({
    required String id,
    required String debtId,
    required double amount,
    required DateTime paymentDate,
    String? notes,
  }) {
    return DebtPayment(
      id: id,
      debtId: debtId,
      amount: amount,
      paymentDate: paymentDate,
      notes: notes,
      createdOn: DateTime.now(),
    );
  }

  // Convert a DebtPayment into a Map object
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debt_id': debtId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'notes': notes,
      'created_on': createdOn.toIso8601String(),
    };
  }

  // Create a DebtPayment from a Map object
  factory DebtPayment.fromMap(Map<String, dynamic> map) {
    return DebtPayment(
      id: map['id'],
      debtId: map['debt_id'],
      amount: map['amount'],
      paymentDate: DateTime.parse(map['payment_date']),
      notes: map['notes'],
      createdOn: DateTime.parse(map['created_on']),
    );
  }
}
