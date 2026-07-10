import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_lock_service.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import 'category_manger.dart';
import 'manage_budget.dart';
import 'privacy_policy.dart';
import '../utilities/constants.dart';

class SettingsScreen extends StatelessWidget {
  static const routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        children: [
          _buildSection(
            context,
            title: 'Categories & Budget',
            children: [
              _buildSettingTile(
                context,
                icon: Icons.category_outlined,
                activeIcon: Icons.category,
                title: 'Manage Categories',
                subtitle: 'Add, edit, or delete expense and income categories',
                onTap: () => Navigator.pushNamed(
                    context, CategoryManagementScreen.routeName),
              ),
              _buildSettingTile(
                context,
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet,
                title: 'Manage Budget',
                subtitle: 'Set monthly budgets for categories',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ManageBudgetScreen()),
                ),
              ),
              _buildSettingTile(
                context,
                icon: Icons.account_balance_outlined,
                activeIcon: Icons.account_balance,
                title: 'Manage Accounts',
                subtitle: 'Add, edit accounts for tracking transactions',
                onTap: () =>
                    Navigator.pushNamed(context, '/account-management'),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing24),
          _buildSection(
            context,
            title: 'Security',
            children: [
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return _buildSettingTile(
                    context,
                    icon: Icons.lock_outline,
                    activeIcon: Icons.lock,
                    title: 'App Lock',
                    subtitle: settings.isAppLockEnabled
                        ? 'Require biometrics or PIN to open the app'
                        : 'App Lock disabled',
                    trailing: Switch(
                      value: settings.isAppLockEnabled,
                      onChanged: (value) =>
                          _handleAppLockToggle(context, settings, value),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing24),
          _buildSection(
            context,
            title: 'Customize',
            children: [
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return _buildAccentColorTile(context, settings);
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.currency_exchange_outlined,
                activeIcon: Icons.currency_exchange,
                title: 'Currency',
                subtitle: 'Change your preferred currency',
                onTap: () {
                  _showCurrencySelectionDialog(context);
                },
              ),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return _buildSettingTile(
                    context,
                    icon: Icons.dark_mode_outlined,
                    activeIcon: Icons.dark_mode,
                    title: 'Dark Mode',
                    subtitle: 'Toggle dark/light theme',
                    trailing: Switch(
                      value: settings.themeMode == ThemeMode.dark,
                      onChanged: (value) {
                        settings.toggleTheme(value);
                      },
                    ),
                  );
                },
              ),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return _buildSettingTile(
                    context,
                    icon: Icons.access_time_outlined,
                    activeIcon: Icons.access_time,
                    title: 'Time Format',
                    subtitle: settings.use24HourFormat
                        ? '24-hour format (14:30)'
                        : '12-hour format (2:30 PM)',
                    trailing: Switch(
                      value: settings.use24HourFormat,
                      onChanged: (value) {
                        settings.toggleTimeFormat(value);
                      },
                    ),
                  );
                },
              ),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return _buildSettingTile(
                    context,
                    icon: Icons.notifications_outlined,
                    activeIcon: Icons.notifications,
                    title: 'Daily Reminder',
                    subtitle: settings.enableNotifications
                        ? 'Remind at ${settings.notificationTime.format(context)}'
                        : 'Daily reminder disabled',
                    trailing: Switch(
                      value: settings.enableNotifications,
                      onChanged: (value) {
                        settings.toggleNotifications(value);
                      },
                    ),
                    onTap: settings.enableNotifications
                        ? () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: settings.notificationTime,
                            );
                            if (picked != null) {
                              settings.setNotificationTime(picked);
                            }
                          }
                        : null,
                  );
                },
              ),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return _buildSettingTile(
                    context,
                    icon: Icons.event_available_outlined,
                    activeIcon: Icons.event_available,
                    title: 'Bill Reminders',
                    subtitle: settings.billRemindersEnabled
                        ? 'Notified the day before bills and debts are due'
                        : 'Bill reminders disabled',
                    trailing: Switch(
                      value: settings.billRemindersEnabled,
                      onChanged: (value) {
                        settings.setBillRemindersEnabled(value);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing24),
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return _buildSection(
                context,
                title: 'Home Screen Widgets',
                children: [
                  _buildHomeWidgetTile(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet,
                    title: 'Balance Card',
                    subtitle: 'Show income, expenses, and monthly balance',
                    value: settings.showHomeBalanceCard,
                    onChanged: settings.setShowHomeBalanceCard,
                  ),
                  _buildHomeWidgetTile(
                    context,
                    icon: Icons.speed_outlined,
                    activeIcon: Icons.speed,
                    title: 'Monthly Budget',
                    subtitle: 'Show budget pace, projection and insights',
                    value: settings.showHomeQuickStats,
                    onChanged: settings.setShowHomeQuickStats,
                  ),
                  _buildHomeWidgetTile(
                    context,
                    icon: Icons.event_repeat_outlined,
                    activeIcon: Icons.event_repeat,
                    title: 'Upcoming Payments',
                    subtitle: 'Show upcoming recurring transactions',
                    value: settings.showHomeUpcomingPayments,
                    onChanged: settings.setShowHomeUpcomingPayments,
                  ),
                  _buildHomeWidgetTile(
                    context,
                    icon: Icons.handshake_outlined,
                    activeIcon: Icons.handshake,
                    title: 'Debt Summary',
                    subtitle: 'Show active debts and overdue totals',
                    value: settings.showHomeDebtSummary,
                    onChanged: settings.setShowHomeDebtSummary,
                  ),
                  _buildHomeWidgetTile(
                    context,
                    icon: Icons.savings_outlined,
                    activeIcon: Icons.savings,
                    title: 'Goals',
                    subtitle: 'Show savings goals and progress',
                    value: settings.showHomeGoals,
                    onChanged: settings.setShowHomeGoals,
                  ),
                  _buildHomeWidgetTile(
                    context,
                    icon: Icons.bar_chart_outlined,
                    activeIcon: Icons.bar_chart,
                    title: 'Budget Chart',
                    subtitle: 'Show budget vs expense chart',
                    value: settings.showHomeBudgetChart,
                    onChanged: settings.setShowHomeBudgetChart,
                  ),
                  _buildHomeWidgetTile(
                    context,
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long,
                    title: 'Recent Transactions',
                    subtitle: 'Show latest transactions on Home',
                    value: settings.showHomeRecentTransactions,
                    onChanged: settings.setShowHomeRecentTransactions,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppDimensions.spacing24),
          _buildSection(
            context,
            title: 'AI Assistant',
            children: [
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return _buildSettingTile(
                    context,
                    icon: Icons.auto_awesome_outlined,
                    activeIcon: Icons.auto_awesome,
                    title: 'Enable AI Assistant',
                    subtitle: settings.aiAssistantEnabled
                        ? 'AI assistant enabled'
                        : 'AI assistant disabled',
                    trailing: Switch(
                      value: settings.aiAssistantEnabled,
                      onChanged: settings.toggleAiAssistant,
                    ),
                  );
                },
              ),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return _buildSettingTile(
                    context,
                    icon: Icons.link_outlined,
                    activeIcon: Icons.link,
                    title: 'Supabase Function URL',
                    subtitle: settings.aiFunctionUrl.isEmpty
                        ? 'Required before using AI'
                        : settings.aiFunctionUrl,
                    onTap: () => _showAiFunctionUrlDialog(context, settings),
                  );
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.privacy_tip_outlined,
                activeIcon: Icons.privacy_tip,
                title: 'AI Privacy',
                subtitle:
                    'AI receives your command plus category/account names, not your full transaction history.',
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing24),
          _buildSection(
            context,
            title: 'Data & Privacy',
            children: [
              _buildSettingTile(
                context,
                icon: Icons.backup_outlined,
                activeIcon: Icons.backup,
                title: 'Create Backup',
                subtitle: 'Export all your data to a ZIP file',
                onTap: () async {
                  await _createBackup(context);
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.table_view_outlined,
                activeIcon: Icons.table_view,
                title: 'Export Transactions CSV',
                subtitle: 'Share a spreadsheet-friendly transaction file',
                onTap: () async {
                  await _exportTransactionsCsv(context);
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.folder_open,
                activeIcon: Icons.folder_open,
                title: 'Manage Backups',
                subtitle: 'View and restore previous backups',
                onTap: () {
                  Navigator.pushNamed(context, '/backup_management');
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.privacy_tip_outlined,
                activeIcon: Icons.privacy_tip,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () {
                  Navigator.pushNamed(context, PrivacyPolicyScreen.routeName);
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing24),
          _buildSection(
            context,
            title: 'About',
            children: [
              _buildSettingTile(
                context,
                icon: Icons.info_outline,
                activeIcon: Icons.info,
                title: 'App Version',
                subtitle: '1.0.0',
                onTap: null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCurrencySelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select Currency'),
          content: SingleChildScrollView(
            child: Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCurrencyOption(context, 'USD', '\$', settings),
                    _buildCurrencyOption(context, 'EUR', '€', settings),
                    _buildCurrencyOption(context, 'INR', '₹', settings),
                    _buildCurrencyOption(context, 'GBP', '£', settings),
                    _buildCurrencyOption(context, 'JPY', '¥', settings),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrencyOption(BuildContext context, String code, String symbol,
      SettingsProvider settings) {
    final isSelected = settings.currencyCode == code;
    return ListTile(
      title: Text('$code ($symbol)'),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        settings.setCurrency(code, symbol);
        Navigator.of(context).pop();
      },
    );
  }

  void _showAccentColorDialog(
    BuildContext context,
    SettingsProvider settings,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accent Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: SettingsProvider.accentColorOptions.map((option) {
            final isSelected =
                settings.accentColor.toARGB32() == option.color.toARGB32();
            return Semantics(
              label: option.name,
              selected: isSelected,
              button: true,
              child: InkWell(
                onTap: () {
                  settings.setAccentColor(option.color);
                  Navigator.of(ctx).pop();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: option.color.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSmall),
                    border: Border.all(
                      color: isSelected
                          ? option.color
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.35),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: option.color,
                          shape: BoxShape.circle,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAiFunctionUrlDialog(
    BuildContext context,
    SettingsProvider settings,
  ) {
    final controller = TextEditingController(text: settings.aiFunctionUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supabase Function URL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://project.supabase.co/functions/v1/finance-ai',
            labelText: 'Function URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              settings.setAiFunctionUrl(controller.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Creating backup...'),
          ],
        ),
      ),
    );

    try {
      final backupService = BackupService();
      final backupPath = await backupService.createBackup();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show success dialog with share option
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Backup Created'),
          content: const Text(
              'Your backup has been created successfully. Would you like to share it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await backupService.shareBackup(backupPath);
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _exportTransactionsCsv(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Creating CSV export...'),
          ],
        ),
      ),
    );

    try {
      final exportService = ExportService();
      final result = await exportService.createTransactionsCsvExport();

      if (!context.mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Transactions Exported'),
          content: Text(
            '${result.rowCount} transactions were exported to ${result.fileName}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await exportService.shareExport(result);
              },
              icon: const Icon(Icons.share),
              label: const Text('Share CSV'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleAppLockToggle(
    BuildContext context,
    SettingsProvider settings,
    bool enable,
  ) async {
    if (!enable) {
      await settings.setAppLockEnabled(false);
      return;
    }

    final available = await AppLockService().isAvailable();
    if (!context.mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Set up a screen lock or biometrics on your device first'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    final authenticated =
        await AppLockService().authenticate(reason: 'Confirm to enable App Lock');
    if (!context.mounted) return;
    if (authenticated) {
      await settings.setAppLockEnabled(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed. App Lock was not enabled.'),
          backgroundColor: AppColors.negative,
        ),
      );
    }
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.spacing16,
            bottom: AppDimensions.spacing8,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppDimensions.spacing8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
        child: Icon(
          onTap != null ? activeIcon : icon,
          color: colorScheme.primary,
          size: AppDimensions.iconMedium,
        ),
      ),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall,
      ),
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  Widget _buildHomeWidgetTile(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildSettingTile(
      context,
      icon: icon,
      activeIcon: activeIcon,
      title: title,
      subtitle: value ? subtitle : 'Hidden from Home',
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
    );
  }

  Widget _buildAccentColorTile(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return _buildSettingTile(
      context,
      icon: Icons.palette_outlined,
      activeIcon: Icons.palette,
      title: 'Accent Color',
      subtitle: settings.accentColorName,
      trailing: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: settings.accentColor,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
          ),
        ),
      ),
      onTap: () => _showAccentColorDialog(context, settings),
    );
  }
}
