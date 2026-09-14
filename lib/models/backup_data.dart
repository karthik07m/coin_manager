class BackupData {
  final String version;
  final DateTime createdAt;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> budgetValues;
  final List<Map<String, dynamic>> budgetTotals;
  final List<Map<String, dynamic>> receipts;
  final List<Map<String, dynamic>> debts;
  final List<Map<String, dynamic>> debtPayments;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> goalContributions;
  final List<Map<String, dynamic>> accounts;
  /// Tombstones for recurring instances the user deleted. Without them a
  /// restore lets every deleted instance regenerate as a duplicate.
  final List<Map<String, dynamic>> recurringSkips;
  final List<Map<String, dynamic>> activityLog;
  final Map<String, dynamic> settings;

  BackupData({
    required this.version,
    required this.createdAt,
    required this.transactions,
    required this.categories,
    required this.budgetValues,
    required this.budgetTotals,
    required this.receipts,
    required this.debts,
    required this.debtPayments,
    this.goals = const [],
    this.goalContributions = const [],
    required this.accounts,
    this.recurringSkips = const [],
    this.activityLog = const [],
    required this.settings,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'transactions': transactions,
      'categories': categories,
      'budget_values': budgetValues,
      'budget_totals': budgetTotals,
      'receipts': receipts,
      'debts': debts,
      'debt_payments': debtPayments,
      'goals': goals,
      'goal_contributions': goalContributions,
      'accounts': accounts,
      'recurring_skips': recurringSkips,
      'activity_log': activityLog,
      'settings': settings,
    };
  }

  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      version: json['version'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      transactions:
          List<Map<String, dynamic>>.from(json['transactions'] as List),
      categories: List<Map<String, dynamic>>.from(json['categories'] as List),
      budgetValues:
          List<Map<String, dynamic>>.from(json['budget_values'] as List),
      budgetTotals:
          List<Map<String, dynamic>>.from(json['budget_totals'] as List),
      receipts: List<Map<String, dynamic>>.from(json['receipts'] as List),
      debts: List<Map<String, dynamic>>.from(json['debts'] ?? []),
      debtPayments:
          List<Map<String, dynamic>>.from(json['debt_payments'] ?? []),
      goals: List<Map<String, dynamic>>.from(json['goals'] ?? []),
      goalContributions:
          List<Map<String, dynamic>>.from(json['goal_contributions'] ?? []),
      accounts: List<Map<String, dynamic>>.from(json['accounts'] ?? []),
      // Absent from backups written before 1.1.0 — default to empty rather
      // than refusing to restore them.
      recurringSkips:
          List<Map<String, dynamic>>.from(json['recurring_skips'] ?? []),
      activityLog: List<Map<String, dynamic>>.from(json['activity_log'] ?? []),
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
    );
  }

  static const String currentVersion = '1.1.0';
}

class BackupInfo {
  final String name;
  final String path;
  final DateTime createdAt;
  final int sizeBytes;

  BackupInfo({
    required this.name,
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
