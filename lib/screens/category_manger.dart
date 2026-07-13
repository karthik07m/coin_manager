import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../models/category.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

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

  /// Add or edit a category via the same bottom-sheet editor style used in
  /// Manage Budget: name field, 5-column icon grid, type toggle, one button.
  Future<void> _showCategoryEditor({Category? category}) async {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedIcon = category?.icon ??
        (categoryIcons.isNotEmpty ? categoryIcons.first : '');
    bool isExpense = category?.isExpense ?? _isExpenseSelected;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      isEditing ? 'Edit category' : 'New category',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      autofocus: !isEditing,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Category name',
                        filled: true,
                        fillColor: context.appBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Type toggle (segmented)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.appBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _sheetTypeSegment(
                            context,
                            label: 'Expense',
                            selected: isExpense,
                            onTap: () => setSheetState(() => isExpense = true),
                          ),
                          _sheetTypeSegment(
                            context,
                            label: 'Income',
                            selected: !isExpense,
                            onTap: () => setSheetState(() => isExpense = false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'ICON',
                      style: AppTextStyles.caption.copyWith(
                        color: context.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 210,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: categoryIcons.length,
                        itemBuilder: (context, index) {
                          final icon = categoryIcons[index];
                          final isSelected = selectedIcon == icon;
                          return GestureDetector(
                            onTap: () =>
                                setSheetState(() => selectedIcon = icon),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.appAccent.withValues(alpha: 0.18)
                                    : context.appBackground,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? context.appAccent
                                      : AppColors.divider
                                          .withValues(alpha: 0.3),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(9),
                              child: Image.asset(
                                icon,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.category, size: 24),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty || selectedIcon.isEmpty) return;
                          Navigator.pop(sheetContext);
                          await _saveCategory(
                            existing: category,
                            name: name,
                            icon: selectedIcon,
                            isExpense: isExpense,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.appAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Save changes' : 'Add category',
                          style: AppTextStyles.button,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    nameController.dispose();
  }

  Widget _sheetTypeSegment(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? context.appAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: selected ? Colors.white : context.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCategory({
    Category? existing,
    required String name,
    required String icon,
    required bool isExpense,
  }) async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    final now = DateTime.now().toIso8601String();
    final category = Category(
      id: existing?.id,
      name: name,
      icon: icon,
      isExpense: isExpense,
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
