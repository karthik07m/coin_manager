class Category {
  final int? id;
  final String name;
  final String icon;
  final bool isExpense;
  final double? budget;
  final String? createdOn;
  final String? modifiedOn;

  Category({
    this.id,
    required this.name,
    required this.icon,
    required this.isExpense,
    this.budget,
    this.createdOn,
    this.modifiedOn,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      isExpense: map['isExpense'] == 1,
      budget: map['budget'],
      createdOn: map['created_on'],
      modifiedOn: map['modified_on'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isExpense': isExpense ? 1 : 0,
      'budget': budget,
      'created_on': createdOn,
      'modified_on': modifiedOn,
    };
  }
}
