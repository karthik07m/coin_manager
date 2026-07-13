import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../models/category.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../widgets/category_editor_sheet.dart';

class CategoryManagementScreen extends StatefulWidget {
  static const routeName = '/crud-category';
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  bool _isExpenseSelected = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    await Provider.of<CategoryProvider>(context, listen: false)
        .fetchAllCategories();
  }

  /// Add or edit a category via the shared bottom-sheet editor (owns its own
  /// controller/focus, so dismissing with the keyboard open is crash-free).
  Future<void> _showCategoryEditor({Category? category}) async {
    final result = await showCategoryEditorSheet(
      context,
      initialName: category?.name,
      initialIcon: category?.icon,
      initialIsExpense: category?.isExpense ?? _isExpenseSelected,
      showTypeToggle: true,
      isEditing: category != null,
    );
    if (result == null || !mounted) return;
    await _saveCategory(existing: category, result: result);
  }

  Future<void> _saveCategory({
    Category? existing,
    required CategoryEditorResult result,
  }) async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    final now = DateTime.now().toIso8601String();
    final category = Category(
      id: existing?.id,
      name: result.name,
      icon: result.icon,
      isExpense: result.isExpense,
      budget: existing?.budget,
      createdOn: existing?.createdOn ?? now,
      modifiedOn: now,
    );

    try {
      if (existing == null) {
        await provider.addCategory(category);
      } else {
        await provider.updateCategory(category);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save category: $e'),
          backgroundColor: AppColors.negative,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete category'),
        content: Text(
          'Delete "${category.name}"? This removes it from budgets and can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await Provider.of<CategoryProvider>(context, listen: false)
          .deleteCategory(category.id ?? 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add category',
            onPressed: () => _showCategoryEditor(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented Expense / Income toggle (same pattern as Charts)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.appSurfaceLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(
                  color: AppColors.divider.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  _buildTypeSelector(true, 'Expense'),
                  _buildTypeSelector(false, 'Income'),
                ],
              ),
            ),
            Expanded(
              child: Consumer<CategoryProvider>(
                builder: (context, categoryProvider, child) {
                  final categories = categoryProvider.categories
                      .where((c) => c.isExpense == _isExpenseSelected)
                      .toList();

                  if (categories.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: categories.length + 1,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      // Trailing "Add category" tile, same as Manage Budget.
                      if (index == categories.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _buildAddTile(context),
                        );
                      }
                      return _buildCategoryRow(context, categories[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(bool isExpense, String label) {
    final isSelected = _isExpenseSelected == isExpense;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isExpenseSelected == isExpense) return;
          setState(() => _isExpenseSelected = isExpense);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? context.appAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? Colors.white : context.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(BuildContext context, Category category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.appSurfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.appAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: category.icon.isNotEmpty
                ? Image.asset(
                    category.icon,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.category,
                      size: 22,
                      color: context.appAccent,
                    ),
                  )
                : Icon(Icons.category, size: 22, color: context.appAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              category.name,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              size: 20,
              color: context.textSecondary,
            ),
            padding: EdgeInsets.zero,
            splashRadius: 20,
            color: context.appSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showCategoryEditor(category: category);
              } else if (value == 'delete') {
                _deleteCategory(category);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.negative),
                    const SizedBox(width: 10),
                    Text(
                      'Delete',
                      style: TextStyle(color: AppColors.negative),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddTile(BuildContext context) {
    return InkWell(
      onTap: () => _showCategoryEditor(),
      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: Border.all(
            color: context.appAccent.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 20, color: context.appAccent),
            const SizedBox(width: 8),
            Text(
              'Add category',
              style: AppTextStyles.bodyLarge.copyWith(
                color: context.appAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.appAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.category_outlined,
              size: 34,
              color: context.appAccent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_isExpenseSelected ? 'expense' : 'income'} categories yet',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to create one',
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: _buildAddTile(context),
          ),
        ],
      ),
    );
  }
}
