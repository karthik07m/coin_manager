import 'dart:math';

import 'package:flutter/material.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

/// Result returned when the user saves the category editor.
class CategoryEditorResult {
  final String name;
  final String icon;
  final bool isExpense;
  final int color;

  const CategoryEditorResult({
    required this.name,
    required this.icon,
    required this.isExpense,
    required this.color,
  });
}

/// Opens the shared add/edit category editor and returns the entered values
/// (or null if dismissed).
///
/// It's a full-screen page with `resizeToAvoidBottomInset: false` and a static
/// layout, so showing/dismissing the keyboard moves nothing — the keyboard
/// simply overlays the scrollable icon grid while the name field (top) and the
/// Save action (app bar) stay put. That avoids the jank of a bottom sheet
/// translating its whole body up for the keyboard every frame.
Future<CategoryEditorResult?> showCategoryEditorSheet(
  BuildContext context, {
  String? initialName,
  String? initialIcon,
  int? initialColor,
  bool initialIsExpense = true,
  bool showTypeToggle = true,
  bool isEditing = false,
}) {
  return Navigator.of(context).push<CategoryEditorResult>(
    PageRouteBuilder<CategoryEditorResult>(
      opaque: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _CategoryEditorPage(
        initialName: initialName,
        initialIcon: initialIcon,
        initialColor: initialColor,
        initialIsExpense: initialIsExpense,
        showTypeToggle: showTypeToggle,
        isEditing: isEditing,
      ),
      transitionsBuilder: (context, animation, secondary, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
    ),
  );
}

class _CategoryEditorPage extends StatefulWidget {
  final String? initialName;
  final String? initialIcon;
  final int? initialColor;
  final bool initialIsExpense;
  final bool showTypeToggle;
  final bool isEditing;

  const _CategoryEditorPage({
    this.initialName,
    this.initialIcon,
    this.initialColor,
    this.initialIsExpense = true,
    this.showTypeToggle = true,
    this.isEditing = false,
  });

  @override
  State<_CategoryEditorPage> createState() => _CategoryEditorPageState();
}

class _CategoryEditorPageState extends State<_CategoryEditorPage> {
  late final TextEditingController _nameController;
  final FocusNode _focusNode = FocusNode();
  late String _selectedIcon;
  late Color _selectedColor;
  late bool _isExpense;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedIcon = widget.initialIcon ??
        (categoryIcons.isNotEmpty ? categoryIcons.first : '');
    // A random start keeps new categories from all defaulting to blue.
    _selectedColor = widget.initialColor != null
        ? Color(widget.initialColor!)
        : AppColors.categoryPalette[
            Random().nextInt(AppColors.categoryPalette.length)];
    _isExpense = widget.initialIsExpense;

    // Focus after the entrance animation so the keyboard doesn't fight it.
    if (!widget.isEditing) {
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _focusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedIcon.isEmpty) return;
    _focusNode.unfocus();
    Navigator.pop(
      context,
      CategoryEditorResult(
        name: name,
        icon: _selectedIcon,
        isExpense: _isExpense,
        color: _selectedColor.toARGB32(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      // Static layout: the keyboard overlays the grid instead of pushing.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit category' : 'New category'),
        actions: [
          TextButton(
            onPressed: _submit,
            child: Text(
              'Save',
              style: AppTextStyles.button.copyWith(color: context.appAccent),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _nameController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Category name',
                  filled: true,
                  fillColor: context.appSurfaceLight,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (widget.showTypeToggle)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.appSurfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _typeSegment('Expense', _isExpense,
                          () => setState(() => _isExpense = true)),
                      _typeSegment('Income', !_isExpense,
                          () => setState(() => _isExpense = false)),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Text(
                'Colour',
                style: AppTextStyles.caption.copyWith(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: AppColors.categoryPalette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) =>
                    _swatch(AppColors.categoryPalette[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
              child: Text(
                'Icon',
                style: AppTextStyles.caption.copyWith(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Scrollable, section-grouped grid fills the rest; the keyboard
            // just overlays its lower part (nothing moves when it opens).
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  for (final group in categoryIconGroups) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          group.label,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        // Max-extent adapts the column count to the width:
                        // ~5 across on phones, more on tablets.
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 76,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _iconTile(group.icons[index]),
                          childCount: group.icons.length,
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(Color color) {
    final isSelected = _selectedColor == color;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Colour swatch',
      child: GestureDetector(
        onTap: () => setState(() => _selectedColor = color),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? context.textPrimary : Colors.transparent,
              width: 3,
            ),
          ),
          child: isSelected
              ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  Widget _iconTile(String icon) {
    final isSelected = _selectedIcon == icon;
    // The selected tile previews the chosen colour, so icon and colour are
    // judged together.
    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = icon),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? _selectedColor.withValues(alpha: 0.18)
              : context.appSurfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? _selectedColor
                : AppColors.divider.withValues(alpha: 0.3),
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
  }

  Widget _typeSegment(String label, bool selected, VoidCallback onTap) {
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
}
