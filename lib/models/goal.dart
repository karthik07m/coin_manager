class Goal {
  final String id;
  String title;
  double targetAmount;
  double currentAmount;
  DateTime? targetDate;
  String? notes;
  final DateTime createdOn;
  late DateTime modifiedOn;

  Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    this.notes,
    required this.createdOn,
    required this.modifiedOn,
  });

  factory Goal.createNew({
    required String id,
    required String title,
    required double targetAmount,
    double currentAmount = 0,
    DateTime? targetDate,
    String? notes,
  }) {
    DateTime now = DateTime.now();
    return Goal(
      id: id,
      title: title,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: targetDate,
      notes: notes,
      createdOn: now,
      modifiedOn: now,
    );
  }

  void update({
    required String title,
    required double targetAmount,
    required double currentAmount,
    DateTime? targetDate,
    String? notes,
  }) {
    this.title = title;
    this.targetAmount = targetAmount;
    this.currentAmount = currentAmount;
    this.targetDate = targetDate;
    this.notes = notes;
    modifiedOn = DateTime.now();
  }

  bool get isAchieved => currentAmount >= targetAmount;

  double getRemainingAmount() {
    final remaining = targetAmount - currentAmount;
    return remaining < 0 ? 0 : remaining;
  }

  double getProgressPercentage() {
    if (targetAmount == 0) return 0;
    return (currentAmount / targetAmount * 100).clamp(0, 100);
  }

  // Days until targetDate (date-only, ignoring time of day).
  // Negative means past the target date by that many days.
  int? getDaysUntilTarget() {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target =
        DateTime(targetDate!.year, targetDate!.month, targetDate!.day);
    return target.difference(today).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': targetDate?.toIso8601String(),
      'notes': notes,
      'created_on': createdOn.toIso8601String(),
      'modified_on': modifiedOn.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      title: map['title'],
      targetAmount: map['target_amount'],
      currentAmount: map['current_amount'],
      targetDate:
          map['target_date'] != null ? DateTime.parse(map['target_date']) : null,
      notes: map['notes'],
      createdOn: DateTime.parse(map['created_on']),
      modifiedOn: DateTime.parse(map['modified_on']),
    );
  }
}
