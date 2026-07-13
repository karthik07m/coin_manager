import 'package:flutter/material.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

/// Result returned when the user saves the category editor sheet.
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

/// Shows the shared add/edit category bottom sheet and returns the entered
/// values (or null if dismissed).
///
/// The sheet is a real [StatefulWidget] that owns its controller and focus
/// node, so they're disposed in the correct order when the route pops. That
/// avoids the `_dependents.isEmpty` framework assertion that an inline
/// StatefulBuilder + focused TextField hit when dismissed with the keyboard
/// still open.
Future<CategoryEditorResult?> showCategoryEditorSheet(
  BuildContext context, {
  String? initialName,
  String? initialIcon,
  bool initialIsExpense = true,
  bool showTypeToggle = true,
  bool isEditing = false,
}) {
  return showModalBottomSheet<CategoryEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CategoryEditorSheet(
      initialName: initialName,
      initialIcon: initialIcon,
      initialIsExpense: initialIsExpense,
      showTypeToggle: showTypeToggle,
      isEditing: isEditing,
    ),
  );
}

class _CategoryEditorSheet extends StatefulWidget {
  final String? initialName;
  final String? initialIcon;
  final bool initialIsExpense;
  final bool showTypeToggle;
  final bool isEditing;

  const _CategoryEditorSheet({
    this.initialName,
    this.initialIcon,
    this.initialIsExpense = true,
    this.showTypeToggle = true,
    this.isEditing = false,
  });

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
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

    // For a new category, open the keyboard only after the sheet has finished
    // sliding in, so the entrance and keyboard animations don't compound into
    // jank (this replaces TextField.autofocus, which fires them together).
    if (!widget.isEditing) {
      Future.delayed(const Duration(milliseconds: 280), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    // Release focus before the node is torn down, then dispose in order.
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
    // Built once per state change (does NOT read the keyboard inset). The
    // RepaintBoundary lets the compositor reuse this subtree's cached layer
    // while it slides for the keyboard, instead of repainting the 20 icons
    // every frame.
    final Widget body = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              widget.isEditing ? 'Edit category' : 'New category',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Category name',
                filled: true,
                fillColor: context.appBackground,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (widget.showTypeToggle) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.appBackground,
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
            ],
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
                  final isSelected = _selectedIcon == icon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.appAccent.withValues(alpha: 0.18)
                            : context.appBackground,
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
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.isEditing ? 'Save changes' : 'Add category',
                  style: AppTextStyles.button,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Only the inset padding depends on the keyboard; the body is reused.
    return _KeyboardInset(child: body);
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

/// Pads its child by the keyboard inset. Isolated so that keyboard-animation
/// rebuilds hit only this widget (the padding), not the sheet body passed as
/// [child], which is reused unchanged frame-to-frame.
class _KeyboardInset extends StatelessWidget {
  final Widget child;

  const _KeyboardInset({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: child,
    );
  }
}
