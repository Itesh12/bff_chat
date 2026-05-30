import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';

class NoteDetailScreen extends GetView<NotesController> {
  const NoteDetailScreen({super.key});

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

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year} at ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final id = Get.parameters['id'];
    final theme = Theme.of(context);

    final borderThemeColor = theme.dividerColor;

    return AppScaffold(
      title: 'View Note',
      actions: [
        Obx(() {
          final note = controller.notes.firstWhereOrNull((n) => n.id == id);
          if (note == null) return const SizedBox.shrink();
          return AppIconButton.secondary(
            icon: note.isFavorite ? Icons.star : Icons.star_border,
            tooltip: 'Favorite',
            onPressed: () => controller.toggleFavorite(note.id),
          );
        }),
        const AppGap.h8(),
        Obx(() {
          final note = controller.notes.firstWhereOrNull((n) => n.id == id);
          if (note == null) return const SizedBox.shrink();
          return AppIconButton.secondary(
            icon: Icons.archive_outlined,
            tooltip: 'Archive Note',
            onPressed: () {
              controller.archiveNote(note.id);
              Get.back();
              AppSnackBar.success(title: 'Archived', message: 'Note moved to archive.');
            },
          );
        }),
        const AppGap.h8(),
        Obx(() {
          final note = controller.notes.firstWhereOrNull((n) => n.id == id);
          if (note == null) return const SizedBox.shrink();
          return AppIconButton.danger(
            icon: Icons.delete_outline,
            tooltip: 'Delete Note',
            onPressed: () {
              AppDialog.delete(
                context,
                title: 'Delete Note?',
                message: 'This will move your note to trash. You can restore it later from archive.',
                onDelete: () {
                  controller.softDeleteNote(note.id);
                  Get.back();
                  AppSnackBar.success(title: 'Deleted', message: 'Note moved to trash.');
                },
              );
            },
          );
        }),
        const AppGap.h12(),
      ],
      body: Obx(() {
        final note = controller.notes.firstWhereOrNull((n) => n.id == id);
        if (note == null) {
          return const Center(child: Text('Note not found.'));
        }

        final category = controller.categories.firstWhereOrNull((c) => c.id == note.categoryId);
        final categoryColor = _parseCategoryColor(context, category?.colorHex);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Tag if active
                    if (category != null) ...[
                      AppChip(
                        label: category.name,
                        color: categoryColor,
                      ),
                      const AppGap.v16(),
                    ],

                    // Note Title
                    SelectableText(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: AppTypography.displayLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: note.title.isEmpty
                            ? theme.textTheme.displayLarge?.color?.withValues(alpha: 0.3)
                            : null,
                      ),
                    ),
                    
                    const AppGap.v8(),

                    // Timestamp indicator
                    Text(
                      'Last saved: ${_formatDateTime(note.updatedAt)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                      ),
                    ),

                    const AppGap.v24(),
                    Container(
                      height: 1,
                      color: borderThemeColor,
                    ),
                    const AppGap.v16(),

                    // Note Body Content
                    SelectableText(
                      note.body.isEmpty ? 'No content' : note.body,
                      style: AppTypography.bodyLarge.copyWith(
                        height: 1.6,
                        color: note.body.isEmpty
                            ? theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.3)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Metadata footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderThemeColor, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created: ${_formatDateTime(note.createdAt)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                  ),
                  if (note.lastOpenedAt != null)
                    Text(
                      'Last viewed: ${_formatDateTime(note.lastOpenedAt!)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
      floatingActionButton: AppButton.primary(
        text: 'Edit Note',
        icon: Icons.edit,
        onPressed: () => Get.toNamed('/notes/editor', arguments: id),
      ),
    );
  }
}
