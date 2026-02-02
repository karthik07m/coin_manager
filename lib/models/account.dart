class Account {
  final int? id;
  String name;
  String icon;
  String color;
  double initialBalance; // Balance when account was created
  double currentBalance; // Calculated from transactions, not stored in DB
  bool isDefault;
  final DateTime createdOn;
  late DateTime modifiedOn;

  Account({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.initialBalance = 0.0,
    this.currentBalance = 0.0, // Will be calculated
    this.isDefault = false,
    required this.createdOn,
    required this.modifiedOn,
  });

  factory Account.createNew({
    required String name,
    required String icon,
    required String color,
    double initialBalance = 0.0,
    bool isDefault = false,
  }) {
    final now = DateTime.now();
    return Account(
      name: name,
      icon: icon,
      color: color,
      initialBalance: initialBalance,
      currentBalance: initialBalance, // Initially same as initial balance
      isDefault: isDefault,
      createdOn: now,
      modifiedOn: now,
    );
  }

  void update({
    required String name,
    required String icon,
    required String color,
  }) {
    this.name = name;
    this.icon = icon;
    this.color = color;
    modifiedOn = DateTime.now();
  }

  // Update current balance (calculated, not persisted)
  void updateCurrentBalance(double calculatedBalance) {
    currentBalance = calculatedBalance;
  }

  // Convert an Account into a Map object
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'balance': initialBalance, // For backward compatibility
      'initial_balance': initialBalance, // For new schema
      'is_default': isDefault ? 1 : 0,
      'created_on': createdOn.toIso8601String(),
      'modified_on': modifiedOn.toIso8601String(),
    };
  }

  // Create an Account from a Map object
  factory Account.fromMap(Map<String, dynamic> map) {
    // Handle both old 'balance' and new 'initial_balance' columns
    final balanceValue =
        (map['initial_balance'] ?? map['balance'] ?? 0.0) as num;
    final initialBal = balanceValue.toDouble();

    return Account(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
      initialBalance: initialBal,
      currentBalance: initialBal, // Will be calculated later by provider
      isDefault: map['is_default'] == 1,
      createdOn: DateTime.parse(map['created_on']),
      modifiedOn: DateTime.parse(map['modified_on']),
    );
  }

  // Helper method to get Color object from hex string
  static int colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return int.parse(buffer.toString(), radix: 16);
  }

  // Helper method to convert Color to hex string
  static String colorToHex(int color) {
    return '#${color.toRadixString(16).substring(2).padLeft(6, '0')}';
  }
}
