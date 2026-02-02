import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/account.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

class AccountFormScreen extends StatefulWidget {
  static const routeName = '/account-form';

  const AccountFormScreen({super.key});

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  String _selectedIcon = 'wallet';
  String _selectedColor = '#4CAF50';
  bool _isDefault = false;
  Account? _existingAccount;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'Wallet', 'icon': 'wallet', 'data': Icons.account_balance_wallet},
    {'name': 'Bank', 'icon': 'account_balance', 'data': Icons.account_balance},
    {'name': 'Credit Card', 'icon': 'credit_card', 'data': Icons.credit_card},
    {'name': 'Debit Card', 'icon': 'payment', 'data': Icons.payment},
    {'name': 'Savings', 'icon': 'savings', 'data': Icons.savings},
  ];

  final List<String> _colorOptions = [
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#FF9800', // Orange
    '#9C27B0', // Purple
    '#F44336', // Red
    '#00BCD4', // Cyan
    '#FFEB3B', // Yellow
    '#795548', // Brown
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccountDetails();
    });
  }

  void _loadAccountDetails() {
    final accountId = ModalRoute.of(context)?.settings.arguments as int?;
    if (accountId != null) {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      _existingAccount = accountProvider.getAccountById(accountId);

      if (_existingAccount != null) {
        setState(() {
          _nameController.text = _existingAccount!.name;
          _selectedIcon = _existingAccount!.icon;
          _selectedColor = _existingAccount!.color;
          _isDefault = _existingAccount!.isDefault;
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (_formKey.currentState!.validate()) {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      bool success;
      if (_existingAccount != null) {
        // Update existing account
        _existingAccount!.update(
          name: _nameController.text,
          icon: _selectedIcon,
          color: _selectedColor,
        );
        success = await accountProvider.updateAccount(_existingAccount!);
      } else {
        // Create new account
        final newAccount = Account.createNew(
          name: _nameController.text,
          icon: _selectedIcon,
          color: _selectedColor,
          isDefault: _isDefault,
        );
        success = await accountProvider.addAccount(newAccount);
      }

      // If user toggled default, update it
      if (success && _isDefault && _existingAccount != null) {
        await accountProvider.setDefaultAccount(_existingAccount!.id!);
      } else if (success && _isDefault && _existingAccount == null) {
        // For new account, reload and set as default
        await accountProvider.loadAccounts();
        final newAccount = accountProvider.accounts
            .firstWhere((acc) => acc.name == _nameController.text);
        await accountProvider.setDefaultAccount(newAccount.id!);
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _existingAccount != null
                  ? 'Account updated successfully'
                  : 'Account created successfully',
            ),
            backgroundColor: AppColors.positive,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save account'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_existingAccount == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.negative, size: 24),
            const SizedBox(width: 8),
            Text('Delete Account', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this account? This action cannot be undone if there are no transactions associated with it.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.negative,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      final success =
          await accountProvider.deleteAccount(_existingAccount!.id!);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: AppColors.positive,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot delete account with existing transactions'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(backgroundColor: context.appBackground),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: Text(
          _existingAccount != null ? 'Edit Account' : 'Add Account',
          style: AppTextStyles.h2,
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_existingAccount != null && !_existingAccount!.isDefault)
            IconButton(
              onPressed: _deleteAccount,
              icon: const Icon(Icons.delete, color: AppColors.negative),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Account Name',
                    hintText: 'e.g., My Savings, Business Account',
                    prefixIcon: const Icon(Icons.title),
                    filled: true,
                    fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an account name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimensions.spacing24),

                // Icon Selector
                Text(
                  'Icon',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _iconOptions.map((option) {
                    final isSelected = _selectedIcon == option['icon'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = option['icon'] as String;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : context.appSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : context.textSecondary.withValues(alpha: 0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              option['data'] as IconData,
                              color: isSelected
                                  ? AppColors.primary
                                  : context.textSecondary,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              option['name'] as String,
                              style: AppTextStyles.caption.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : context.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppDimensions.spacing24),

                // Color Selector
                Text(
                  'Color',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colorOptions.map((colorHex) {
                    final color = Color(Account.colorFromHex(colorHex));
                    final isSelected = _selectedColor == colorHex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = colorHex;
                        });
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 28)
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppDimensions.spacing24),

                // Set as Default Toggle
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacing16),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: _isDefault
                            ? AppColors.primary
                            : context.textSecondary,
                      ),
                      const SizedBox(width: AppDimensions.spacing12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set as Default Account',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Use this account for new transactions',
                              style: AppTextStyles.caption.copyWith(
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isDefault,
                        onChanged: (value) {
                          setState(() {
                            _isDefault = value;
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spacing32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _saveAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                    ),
                    child: Text(
                      _existingAccount != null
                          ? 'Update Account'
                          : 'Save Account',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
