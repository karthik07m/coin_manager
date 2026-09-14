enum FinanceTemplateKind { monthlyPayment, savingsGoal }

/// Drafts only: opening one never writes financial records.
class FinanceTemplate {
  final String id;
  final String title;
  final String description;
  final FinanceTemplateKind kind;
  final bool india;
  final List<String> categoryNames;

  const FinanceTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    this.india = false,
    this.categoryNames = const [],
  });
}

const financeTemplates = [
  FinanceTemplate(
      id: 'rent',
      title: 'Rent',
      description: 'Your monthly home payment',
      kind: FinanceTemplateKind.monthlyPayment,
      categoryNames: ['Rent', 'House Rent', 'Bill', 'Bills']),
  FinanceTemplate(
      id: 'utilities',
      title: 'Utilities',
      description: 'Electricity, water, or internet',
      kind: FinanceTemplateKind.monthlyPayment,
      categoryNames: ['Utilities', 'Bill', 'Bills']),
  FinanceTemplate(
      id: 'subscription',
      title: 'Subscription',
      description: 'A monthly membership or streaming service',
      kind: FinanceTemplateKind.monthlyPayment,
      categoryNames: ['Subscriptions', 'Subscription', 'Bill']),
  FinanceTemplate(
      id: 'emergency',
      title: 'Emergency fund',
      description: 'Build a cushion for unexpected costs',
      kind: FinanceTemplateKind.savingsGoal),
  FinanceTemplate(
      id: 'holiday',
      title: 'Holiday fund',
      description: 'Set money aside for your next trip',
      kind: FinanceTemplateKind.savingsGoal),
  FinanceTemplate(
      id: 'milk',
      title: 'Milk bill',
      description: 'Plan your monthly milk payment',
      kind: FinanceTemplateKind.monthlyPayment,
      india: true,
      categoryNames: ['Groceries', 'Food', 'Bill']),
  FinanceTemplate(
      id: 'domestic-help',
      title: 'Domestic help',
      description: 'A monthly household payment',
      kind: FinanceTemplateKind.monthlyPayment,
      india: true,
      categoryNames: ['Household', 'Utilities', 'Bill', 'Bills']),
  FinanceTemplate(
      id: 'groceries',
      title: 'Household groceries',
      description: 'A monthly payment to your grocery shop',
      kind: FinanceTemplateKind.monthlyPayment,
      india: true,
      categoryNames: ['Groceries', 'Food']),
  FinanceTemplate(
      id: 'emi',
      title: 'Loan EMI',
      description: 'Track a monthly loan installment',
      kind: FinanceTemplateKind.monthlyPayment,
      india: true,
      categoryNames: ['Loan EMI', 'EMI', 'Loans', 'Bill', 'Bills']),
  FinanceTemplate(
      id: 'school',
      title: 'School fees',
      description: 'Save toward the next term’s fees',
      kind: FinanceTemplateKind.savingsGoal,
      india: true),
  FinanceTemplate(
      id: 'insurance',
      title: 'Annual insurance premium',
      description: 'Prepare for your next annual renewal',
      kind: FinanceTemplateKind.savingsGoal,
      india: true),
  FinanceTemplate(
      id: 'festival',
      title: 'Festival fund',
      description: 'Choose a festival, amount, and target date',
      kind: FinanceTemplateKind.savingsGoal,
      india: true),
  FinanceTemplate(
      id: 'family-event',
      title: 'Family celebration',
      description: 'Plan for a wedding or another family event',
      kind: FinanceTemplateKind.savingsGoal,
      india: true),
];
