import 'package:flutter/material.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

/// Result returned when the user saves the category editor.
class CategoryEditorResult {
  final String name;
  final String icon;
  final bool isExpense;

  const CategoryEditorResult({
    required this.name,
    required this.icon,
    required this.isExpense,
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
  final bool initialIsExpense;
  final bool showTypeToggle;
  final bool isEditing;

  const _CategoryEditorPage({
    this.initialName,
    this.initialIcon,
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
  late bool _isExpense;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedIcon = widget.initialIcon ??
        (categoryIcons.isNotEmpty ? categoryIcons.first : '');
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
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Text(
                'ICON',
                style: AppTextStyles.caption.copyWith(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            // Scrollable grid fills the rest; the keyboard just overlays its
            // lower part (nothing here moves when the keyboard opens/closes).
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: categoryIcons.length,
                itemBuilder: (context, index) {
                  final icon = categoryIcons[index];
                  final isSelected = _selectedIcon == icon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.appAccent.withValues(alpha: 0.18)
                            : context.appSurfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? context.appAccent
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
                },
              ),
            ),
          ],
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
