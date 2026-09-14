import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_template.dart';
import '../providers/settings_provider.dart';
import '../utilities/page_transitions.dart';
import '../utilities/responsive.dart';
import 'goal_form_screen.dart';
import 'regional_preferences_screen.dart';
import 'transaction_form.dart';

class FinanceTemplatesScreen extends StatelessWidget {
  const FinanceTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final india =
        context.watch<SettingsProvider>().regionalPreferences.indiaTemplates;
    final templates = financeTemplates.where((t) => !t.india || india).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Payment & savings templates')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Start with the everyday essentials',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Pick a template, then choose your amount, account, '
                    'and date. Everything is editable before you save.'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        PageTransitions.fadeUp(
                            const RegionalPreferencesScreen())),
                    icon: const Icon(Icons.tune),
                    label: Text(india
                        ? 'India suggestions included'
                        : 'Regional preferences'),
                  ),
                ),
                for (final kind in FinanceTemplateKind.values) ...[
                  const SizedBox(height: 16),
                  Text(
                      kind == FinanceTemplateKind.monthlyPayment
                          ? 'Monthly payments'
                          : 'Savings goals',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (kind == FinanceTemplateKind.monthlyPayment)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                          'Uses recurring transactions. This does not set up '
                          'bank AutoPay. Stop repeating when a payment ends.'),
                    ),
                  for (final template in templates.where((t) => t.kind == kind))
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Icon(kind == FinanceTemplateKind.monthlyPayment
                            ? Icons.event_repeat
                            : Icons.savings_outlined),
                        title: Text(template.title),
                        subtitle: Text(template.description),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                            PageTransitions.fadeUp(
                                kind == FinanceTemplateKind.monthlyPayment
                                    ? TransactionForm(template: template)
                                    : GoalFormScreen(
                                        initialTitle: template.title))),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
