class GoalContribution {
  final String id;
  final String goalId;
  double amount;
  DateTime contributionDate;
  String? notes;
  final DateTime createdOn;

  GoalContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.contributionDate,
    this.notes,
    required this.createdOn,
  });

  factory GoalContribution.createNew({
    required String id,
    required String goalId,
    required double amount,
    required DateTime contributionDate,
    String? notes,
  }) {
    return GoalContribution(
      id: id,
      goalId: goalId,
      amount: amount,
      contributionDate: contributionDate,
      notes: notes,
      createdOn: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_id': goalId,
      'amount': amount,
      'contribution_date': contributionDate.toIso8601String(),
      'notes': notes,
      'created_on': createdOn.toIso8601String(),
    };
  }

  factory GoalContribution.fromMap(Map<String, dynamic> map) {
    return GoalContribution(
      id: map['id'],
      goalId: map['goal_id'],
      amount: map['amount'],
      contributionDate: DateTime.parse(map['contribution_date']),
      notes: map['notes'],
      createdOn: DateTime.parse(map['created_on']),
    );
  }
}
