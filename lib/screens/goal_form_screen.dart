import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/goal_provider.dart';
import '../utilities/id_generator.dart';
import '../models/goal.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../widgets/calculator_field.dart';

class GoalFormScreen extends StatefulWidget {
  static const String routeName = '/goal-form';
  final String? goalId;

  const GoalFormScreen({super.key, this.goalId});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _targetAmountController;
  late TextEditingController _currentAmountController;
  late TextEditingController _notesController;

  DateTime? _targetDate;
  Goal? _existingGoal;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _targetAmountController = TextEditingController();
    _currentAmountController = TextEditingController(text: '0');
    _notesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGoalDetails();
    });
  }

  Future<void> _loadGoalDetails() async {
    if (widget.goalId != null) {
      final goalProvider = Provider.of<GoalProvider>(context, listen: false);
      _existingGoal = goalProvider.getGoalById(widget.goalId!);

      if (_existingGoal != null) {
        setState(() {
          _titleController.text = _existingGoal!.title;
          _targetAmountController.text =
              _existingGoal!.targetAmount.toStringAsFixed(2);
          _currentAmountController.text =
              _existingGoal!.currentAmount.toStringAsFixed(2);
          _targetDate = _existingGoal!.targetDate;
          if (_existingGoal!.notes != null) {
            _notesController.text = _existingGoal!.notes!;
          }
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  void _showFormError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.negative,
      ),
    );
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    final targetAmount = double.tryParse(
        _targetAmountController.text.replaceAll(',', '').trim());
    if (targetAmount == null || targetAmount <= 0) {
      _showFormError('Please enter a valid target amount');
      return;
    }

    final currentAmountText =
        _currentAmountController.text.replaceAll(',', '').trim();
    final currentAmount =
        currentAmountText.isEmpty ? 0.0 : double.tryParse(currentAmountText);
    if (currentAmount == null || currentAmount < 0) {
      _showFormError('Please enter a valid starting amount');
      return;
    }

    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final notes = _notesController.text.trim().isNotEmpty
        ? _notesController.text.trim()
        : null;

    Goal goal;
    if (_existingGoal != null) {
      _existingGoal!.update(
        title: _titleController.text.trim(),
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        targetDate: _targetDate,
        notes: notes,
      );
      goal = _existingGoal!;
      await goalProvider.updateGoal(goal);
    } else {
      goal = Goal.createNew(
        id: newId(),
        title: _titleController.text.trim(),
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        targetDate: _targetDate,
        notes: notes,
      );
      await goalProvider.addGoal(goal);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _existingGoal != null
              ? 'Goal updated successfully'
              : 'Goal added successfully',
        ),
        backgroundColor: AppColors.positive,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _deleteGoal() async {
    if (_existingGoal == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.negative, size: 24),
            const SizedBox(width: 8),
            Text('Delete Goal', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this goal? Its contribution history will also be removed.',
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
      final goalProvider = Provider.of<GoalProvider>(context, listen: false);
      await goalProvider.deleteGoal(_existingGoal!.id);
      if (!mounted) return;
      Navigator.pop(context);
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
          _existingGoal != null ? 'Edit Goal' : 'Add Goal',
        ),
        elevation: 0,
        actions: [
          if (_existingGoal != null)
            IconButton(
              onPressed: _deleteGoal,
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
                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g., Emergency Fund, Vacation, New Laptop',
                    prefixIcon: const Icon(Icons.flag_outlined),
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
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimensions.spacing16),

                Text(
                  'Target Amount',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                CalculatorTextFormField(
                  controller: _targetAmountController,
                ),

                const SizedBox(height: AppDimensions.spacing16),

                Text(
                  'Already Saved',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                CalculatorTextFormField(
                  controller: _currentAmountController,
                ),

                const SizedBox(height: AppDimensions.spacing16),

                // Target Date Field
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: context.appAccent,
                        ),
                        const SizedBox(width: AppDimensions.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target Date (Optional)',
                                style: AppTextStyles.caption.copyWith(
                                  color: context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _targetDate != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(_targetDate!)
                                    : 'No target date set',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        if (_targetDate != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _targetDate = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacing16),

                // Notes Field
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Add any additional details...',
                    prefixIcon: const Icon(Icons.notes),
                    filled: true,
                    fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacing32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _saveGoal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appAccent,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                    ),
                    child: Text(
                      _existingGoal != null ? 'Update Goal' : 'Save Goal',
                      style: AppTextStyles.button,
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
