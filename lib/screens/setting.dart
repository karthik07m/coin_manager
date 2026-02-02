import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
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
            title: 'Preferences',
            children: [
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
      trailing:
          isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: () {
        settings.setCurrency(code, symbol);
        Navigator.of(context).pop();
      },
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
}
