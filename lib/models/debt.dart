enum DebtStatus { active, paid, overdue }

class Debt {
  final String id;
  String title;
  double amount;
  double amountPaid;
  String debtorName;
  bool isLiability; // true = money I owe, false = money owed to me
  DateTime? dueDate;
  double? interestRate;
  String? notes;
  bool isRecurring; // true if this is a monthly recurring payment
  double? recurringAmount; // fixed monthly amount for recurring debts
  DebtStatus status;
  final DateTime createdOn;
  late DateTime modifiedOn;

  Debt({
    required this.id,
    required this.title,
    required this.amount,
    required this.amountPaid,
    required this.debtorName,
    required this.isLiability,
    this.dueDate,
    this.interestRate,
    this.notes,
    this.isRecurring = false,
    this.recurringAmount,
    required this.status,
    required this.createdOn,
    required this.modifiedOn,
  });

  factory Debt.createNew({
    required String id,
    required String title,
    required double amount,
    required String debtorName,
    required bool isLiability,
    double amountPaid = 0,
    DateTime? dueDate,
    double? interestRate,
    String? notes,
    bool isRecurring = false,
    double? recurringAmount,
  }) {
    DateTime now = DateTime.now();
    return Debt(
      id: id,
      title: title,
      amount: amount,
      amountPaid: amountPaid,
      debtorName: debtorName,
      isLiability: isLiability,
      dueDate: dueDate,
      interestRate: interestRate,
      notes: notes,
      isRecurring: isRecurring,
      recurringAmount: recurringAmount,
      status: DebtStatus.active,
      createdOn: now,
      modifiedOn: now,
    );
  }

  void update({
    required String title,
    required double amount,
    required double amountPaid,
    required String debtorName,
    required bool isLiability,
    DateTime? dueDate,
    double? interestRate,
    String? notes,
    bool? isRecurring,
    double? recurringAmount,
  }) {
    this.title = title;
    this.amount = amount;
    this.amountPaid = amountPaid;
    this.debtorName = debtorName;
    this.isLiability = isLiability;
    this.dueDate = dueDate;
    this.interestRate = interestRate;
    this.notes = notes;
    if (isRecurring != null) this.isRecurring = isRecurring;
    this.recurringAmount = recurringAmount;
    modifiedOn = DateTime.now();

    // Update status based on payment
    if (amountPaid >= amount) {
      status = DebtStatus.paid;
    } else if (dueDate != null &&
        DateTime.now().isAfter(dueDate) &&
        amountPaid < amount) {
      status = DebtStatus.overdue;
    } else {
      status = DebtStatus.active;
    }
  }

  double getRemainingAmount() {
    return amount - amountPaid;
  }

  double getProgressPercentage() {
    if (amount == 0) return 0;
    return (amountPaid / amount * 100).clamp(0, 100);
  }

  void updateStatus() {
    if (amountPaid >= amount) {
      status = DebtStatus.paid;
    } else if (dueDate != null &&
        DateTime.now().isAfter(dueDate as DateTime) &&
        amountPaid < amount) {
      status = DebtStatus.overdue;
    } else {
      status = DebtStatus.active;
    }
  }

  // Convert a Debt into a Map object
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'amount_paid': amountPaid,
      'debtor_name': debtorName,
      'is_liability': isLiability ? 1 : 0,
      'due_date': dueDate?.toIso8601String(),
      'interest_rate': interestRate,
      'notes': notes,
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_amount': recurringAmount,
      'status': status.index,
      'created_on': createdOn.toIso8601String(),
      'modified_on': modifiedOn.toIso8601String(),
    };
  }

  // Create a Debt from a Map object
  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      amountPaid: map['amount_paid'],
      debtorName: map['debtor_name'],
      isLiability: map['is_liability'] == 1,
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      interestRate: map['interest_rate'],
      notes: map['notes'],
      isRecurring: (map['is_recurring'] ?? 0) == 1,
      recurringAmount: map['recurring_amount'],
      status: DebtStatus.values[map['status']],
      createdOn: DateTime.parse(map['created_on']),
      modifiedOn: DateTime.parse(map['modified_on']),
    );
  }
}
