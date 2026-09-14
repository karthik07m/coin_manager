import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../screens/regional_preferences_screen.dart';
import '../screens/finance_templates_screen.dart';
import '../utilities/page_transitions.dart';

class IndiaSetupCard extends StatefulWidget {
  const IndiaSetupCard({super.key});

  @override
  State<IndiaSetupCard> createState() => _IndiaSetupCardState();
}

class _IndiaSetupCardState extends State<IndiaSetupCard> {
  bool _dismissing = false;

  Future<void> _personalize() async {
    final saved = await Navigator.of(context).push<bool>(
      PageTransitions.fadeUp(
          const RegionalPreferencesScreen(suggestIndia: true)),
    );
    if (!mounted || saved != true) return;
    await Navigator.of(context).push(
      PageTransitions.fadeUp(const FinanceTemplatesScreen()),
    );
  }

  Future<void> _dismiss() async {
    setState(() => _dismissing = true);
    try {
      await context.read<SettingsProvider>().dismissIndiaSetup();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save your choice. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _dismissing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SettingsProvider>().shouldSuggestIndiaSetup) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Personalize for India',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                  'Try household payment templates and April–March reports. '
                  'Choose what works for you.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _dismissing ? null : _personalize,
                    child: const Text('Personalize'),
                  ),
                  TextButton(
                    onPressed: _dismissing ? null : _dismiss,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
