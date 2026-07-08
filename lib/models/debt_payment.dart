class DebtPayment {
  final String id;
  final String debtId;
  double amount;
  DateTime paymentDate;
  String? notes;
  // The transaction created for this settlement, if the user chose to
  // record it in their spending too.
  String? transactionId;
  final DateTime createdOn;

  DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paymentDate,
    this.notes,
    this.transactionId,
    required this.createdOn,
  });

  factory DebtPayment.createNew({
    required String id,
    required String debtId,
    required double amount,
    required DateTime paymentDate,
    String? notes,
    String? transactionId,
  }) {
    return DebtPayment(
      id: id,
      debtId: debtId,
      amount: amount,
      paymentDate: paymentDate,
      notes: notes,
      transactionId: transactionId,
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
      'transaction_id': transactionId,
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
      transactionId: map['transaction_id'],
      createdOn: DateTime.parse(map['created_on']),
    );
  }
}
