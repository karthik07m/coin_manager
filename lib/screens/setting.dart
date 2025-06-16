import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_manger.dart';
import 'manage_budget.dart';
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
                  // TODO: Implement currency selection
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Currency selection coming soon!')),
                  );
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.dark_mode_outlined,
                activeIcon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: 'Toggle dark/light theme',
                trailing: Switch(
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (value) {
                    // TODO: Implement theme switching
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Theme switching coming soon!')),
                    );
                  },
                ),
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
                title: 'Backup & Restore',
                subtitle: 'Export or import your data',
                onTap: () {
                  // TODO: Implement backup/restore
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Backup feature coming soon!')),
                  );
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.privacy_tip_outlined,
                activeIcon: Icons.privacy_tip,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () {
                  // TODO: Implement privacy policy
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Privacy policy coming soon!')),
                  );
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
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
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
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppDimensions.spacing8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
        child: Icon(
          onTap != null ? activeIcon : icon,
          color: AppColors.primary,
          size: AppDimensions.iconMedium,
        ),
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall,
      ),
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
