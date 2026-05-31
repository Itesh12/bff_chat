import 'package:flutter/material.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/domain/notes/category_entity.dart';

class NoteEditorForm extends StatelessWidget {
  final String title;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final int wordCount;
  final int? revision;
  final bool isSaving;
  final String? selectedCategoryId;
  final List<CategoryEntity> categories;
  final ValueChanged<CategoryEntity?> onCategorySelected;
  final VoidCallback? onBackTap;
  final VoidCallback? onDelete;

  const NoteEditorForm({
    super.key,
    required this.title,
    required this.titleController,
    required this.bodyController,
    required this.wordCount,
    this.revision,
    required this.isSaving,
    this.selectedCategoryId,
    required this.categories,
    required this.onCategorySelected,
    this.onBackTap,
    this.onDelete,
  });

  Color _parseCategoryColor(BuildContext context, String? hexString) {
    if (hexString == null || hexString.length != 6) {
      return context.colors.disabled;
    }
    try {
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (_) {
      return context.colors.disabled;
    }
  }

  void _showCategoryPicker(BuildContext context) {
    final theme = Theme.of(context);
    AppBottomSheet.show(
      context,
      title: 'Assign Category',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
            onTap: () {
              onCategorySelected(null);
              Navigator.pop(context);
            },
            child: Row(
              children: [
                Icon(Icons.label_off, color: theme.iconTheme.color?.withValues(alpha: 0.6)),
                const AppGap.h16(),
                const Expanded(
                  child: Text('Uncategorized', style: AppTypography.bodyMedium),
                ),
                if (selectedCategoryId == null)
                  Icon(Icons.check, color: theme.primaryColor),
              ],
            ),
          ),
          const AppGap.v8(),
          Container(
            height: 200,
            color: Colors.transparent,
            child: categories.isEmpty
                ? const Center(
                    child: Text('No categories created yet.'),
                  )
                : ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = selectedCategoryId == cat.id;
                      final color = Color(int.parse('FF${cat.colorHex}', radix: 16));
                      
                      return AppCard(
                        margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                        onTap: () {
                          onCategorySelected(cat);
                          Navigator.pop(context);
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: color,
                            ),
                            const AppGap.h16(),
                            Expanded(
                              child: Text(cat.name, style: AppTypography.bodyMedium),
                            ),
                            if (isSelected)
                              Icon(Icons.check, color: theme.primaryColor),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolbarBg = theme.scaffoldBackgroundColor;
    final toolbarBorder = theme.dividerColor;

    final activeCategory = categories.cast<CategoryEntity?>().firstWhere((c) => c?.id == selectedCategoryId, orElse: () => null);
    final color = _parseCategoryColor(context, activeCategory?.colorHex);

    return AppScaffold(
      title: title,
      leading: onBackTap != null
          ? AppIconButton.secondary(
              icon: Icons.arrow_back,
              onPressed: onBackTap,
              tooltip: 'Back',
            )
          : null,
      actions: [
        if (onDelete != null)
          AppIconButton.danger(
            icon: Icons.delete_outline_rounded,
            onPressed: onDelete,
            tooltip: 'Delete Note',
          ),
        Center(
          child: GestureDetector(
            onTap: () => _showCategoryPicker(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 6,
                    backgroundColor: color,
                  ),
                  const AppGap.h8(),
                  Text(
                    activeCategory?.name ?? 'Category',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: activeCategory != null ? color : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s16),
            child: Container(
              height: 16,
              width: 16,
              color: Colors.transparent,
              child: isSaving
                  ? const AppLoading.small()
                  : Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: theme.primaryColor.withValues(alpha: 0.6),
                    ),
            ),
          ),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s4),
            child: AppTextField(
              controller: titleController,
              hintText: 'Note Title',
              borderless: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Container(height: 1, color: toolbarBorder),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: AppTextField.multiline(
                controller: bodyController,
                hintText: 'Start writing...',
                borderless: true,
              ),
            ),
          ),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: toolbarBg,
              border: Border(top: BorderSide(color: toolbarBorder, width: 1.0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$wordCount ${wordCount == 1 ? 'word' : 'words'}',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                  ),
                ),
                if (revision != null)
                  Text(
                    'Revision $revision',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.primaryColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
