import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/regional_preferences.dart';
import '../providers/settings_provider.dart';
import '../utilities/financial_year.dart';
import '../utilities/responsive.dart';

class RegionalPreferencesScreen extends StatefulWidget {
  final bool suggestIndia;
  const RegionalPreferencesScreen({super.key, this.suggestIndia = false});

  @override
  State<RegionalPreferencesScreen> createState() =>
      _RegionalPreferencesScreenState();
}

class _RegionalPreferencesScreenState extends State<RegionalPreferencesScreen> {
  RegionalPreferences? _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = context.read<SettingsProvider>();
    await settings.ready;
    if (!mounted) return;
    final saved = settings.regionalPreferences;
    setState(() {
      _draft = widget.suggestIndia && !saved.indiaSetupHandled
          ? saved.copyWith(indiaTemplates: true, financialYearStartMonth: 4)
          : saved;
    });
  }

  Future<void> _save() async {
    if (_saving || _draft == null) return;
    setState(() => _saving = true);
    try {
      await context
          .read<SettingsProvider>()
          .setRegionalPreferences(_draft!.copyWith(indiaSetupHandled: true));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save preferences. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.suggestIndia
              ? 'Personalize for India'
              : 'Regional preferences')),
      body: draft == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: context.maxContentWidth),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('Make Coinly fit your life',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                          'Choose helpful templates and the year used in '
                          'your expense chart. These choices work with any currency.'),
                      const SizedBox(height: 24),
                      Card(
                        child: SwitchListTile.adaptive(
                          title: const Text('India template suggestions'),
                          subtitle:
                              const Text('Milk bills, domestic help, loan EMI, '
                                  'school fees, and festival savings'),
                          value: draft.indiaTemplates,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                    _draft =
                                        draft.copyWith(indiaTemplates: value);
                                  }),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Financial year',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: draft.financialYearStartMonth,
                        decoration: const InputDecoration(
                          labelText: 'Year starts in',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(
                            12,
                            (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text(DateFormat.MMMM()
                                      .format(DateTime(2000, index + 1))),
                                )),
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    _draft = draft.copyWith(
                                        financialYearStartMonth: value);
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      Text(_yearPreview(draft.financialYearStartMonth)),
                      const SizedBox(height: 8),
                      Text(
                          'April–March is available for India. Choose any start '
                          'month that suits you. Monthly budgets keep their current dates.',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: Text(_saving ? 'Saving…' : 'Save preferences'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _yearPreview(int startMonth) {
    final year =
        FinancialYear.containing(DateTime.now(), startMonth: startMonth);
    final format = DateFormat('MMM yyyy');
    return 'Current reporting year: ${format.format(year.start)} – '
        '${format.format(year.monthAt(11))}';
  }
}
