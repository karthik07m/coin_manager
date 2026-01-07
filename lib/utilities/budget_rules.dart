// Budget allocation rules and category mappings

enum BudgetRuleType {
  rule50_30_20, // 50% Needs, 30% Wants, 20% Savings
  rule60_20_20, // 60% Needs, 20% Wants, 20% Savings
  custom,
}

enum CategoryType {
  needs,
  wants,
  savings,
}

class BudgetRule {
  final String name;
  final String description;
  final BudgetRuleType type;
  final Map<CategoryType, double> percentages;

  const BudgetRule({
    required this.name,
    required this.description,
    required this.type,
    required this.percentages,
  });
}

// Predefined budget rules
const List<BudgetRule> budgetRules = [
  BudgetRule(
    name: '50/30/20 Rule',
    description: '50% Needs, 30% Wants, 20% Savings',
    type: BudgetRuleType.rule50_30_20,
    percentages: {
      CategoryType.needs: 0.50,
      CategoryType.wants: 0.30,
      CategoryType.savings: 0.20,
    },
  ),
  BudgetRule(
    name: '60/20/20 Rule',
    description: '60% Needs, 20% Wants, 20% Savings',
    type: BudgetRuleType.rule60_20_20,
    percentages: {
      CategoryType.needs: 0.60,
      CategoryType.wants: 0.20,
      CategoryType.savings: 0.20,
    },
  ),
];

// Category name to CategoryType mapping
// This maps your app's category names to budget rule types
Map<String, CategoryType> getCategoryTypeMapping() {
  return {
    // Needs (Essential expenses)
    'Food': CategoryType.needs,
    'Groceries': CategoryType.needs,
    'Transport': CategoryType.needs,
    'Bill': CategoryType.needs,
    'Diet': CategoryType.needs,

    // Wants (Discretionary spending)
    'Shopping': CategoryType.wants,
    'Entertainment': CategoryType.wants,
    'Travel': CategoryType.wants,

    // Savings/Income
    'Salary': CategoryType.savings,
    'Bonus': CategoryType.savings,
    'Stocks': CategoryType.savings,
    'Budget': CategoryType.savings,
    'Other': CategoryType.wants, // Default to wants
  };
}

// Calculate budget allocation for categories based on rule
Map<String, double> calculateBudgetAllocation({
  required double totalBudget,
  required BudgetRule rule,
  required List<String> categoryNames,
}) {
  final categoryTypeMap = getCategoryTypeMapping();
  final Map<String, double> allocation = {};

  // Group categories by type
  final Map<CategoryType, List<String>> categoriesByType = {
    CategoryType.needs: [],
    CategoryType.wants: [],
    CategoryType.savings: [],
  };

  for (var categoryName in categoryNames) {
    final type = categoryTypeMap[categoryName] ?? CategoryType.wants;
    categoriesByType[type]!.add(categoryName);
  }

  // Calculate allocation for each category
  for (var entry in categoriesByType.entries) {
    final type = entry.key;
    final categories = entry.value;

    if (categories.isEmpty) continue;

    final typePercentage = rule.percentages[type] ?? 0.0;
    final typeTotal = totalBudget * typePercentage;
    final perCategoryAmount = typeTotal / categories.length;

    for (var categoryName in categories) {
      allocation[categoryName] = perCategoryAmount;
    }
  }

  return allocation;
}
