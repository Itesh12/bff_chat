import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';

class HiddenHomeScreen extends GetView<HiddenHomeController> {
  const HiddenHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: controller.onUserInteraction,
      onPanDown: (_) => controller.onUserInteraction(),
      child: AppScaffold(
        title: 'Private Vault',
        actions: [
          AppIconButton.secondary(
            icon: Icons.logout_rounded,
            tooltip: 'Lock Vault',
            onPressed: controller.logout,
          ),
          const AppGap.h16(),
        ],
        body: Obx(() {
          if (controller.notes.isEmpty) {
            return AppEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Private Vault is Empty',
              message: 'Notes added here are fully encrypted with SQLCipher and are completely isolated from standard notes.',
              ctaLabel: 'Add Secret Note',
              onCtaTap: () => _showAddNoteBottomSheet(context),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.s16),
            itemCount: controller.notes.length,
            itemBuilder: (context, index) {
              final note = controller.notes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                child: AppCard(
                  onTap: () => _showEditNoteBottomSheet(context, note),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              note.title.isEmpty ? 'Untitled Note' : note.title,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              AppIconButton.primary(
                                icon: note.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: note.isFavorite ? Colors.amber : null,
                                onPressed: () => controller.toggleFavorite(note.id),
                              ),
                              AppIconButton.danger(
                                icon: Icons.delete_outline_rounded,
                                onPressed: () => _showDeleteConfirmation(context, note.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const AppGap.v8(),
                      Text(
                        note.body,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const AppGap.v12(),
                      Text(
                        'Last modified: ${_formatDate(note.updatedAt)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
        floatingActionButton: AppButton.primary(
          text: 'New Note',
          icon: Icons.add,
          onPressed: () => _showAddNoteBottomSheet(context),
        ),
      ),
    );
  }

  void _showAddNoteBottomSheet(BuildContext context) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    AppBottomSheet.show(
      context,
      title: 'New Secret Note',
      isScrollControlled: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: titleController,
              hintText: 'Note Title',
              labelText: 'Title',
              autofocus: true,
            ),
            const AppGap.v16(),
            AppTextField.multiline(
              controller: bodyController,
              hintText: 'Type your secret note here...',
              labelText: 'Body',
              minLines: 5,
            ),
            const AppGap.v24(),
            AppButton.primary(
              text: 'Save Note',
              onPressed: () async {
                final title = titleController.text.trim();
                final body = bodyController.text.trim();
                if (title.isNotEmpty || body.isNotEmpty) {
                  await controller.createNote(title, body);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            const AppGap.v12(),
          ],
        ),
      ),
    );
  }

  void _showEditNoteBottomSheet(BuildContext context, HiddenNoteEntity note) {
    final titleController = TextEditingController(text: note.title);
    final bodyController = TextEditingController(text: note.body);

    controller.onUserInteraction();

    AppBottomSheet.show(
      context,
      title: 'Edit Secret Note',
      isScrollControlled: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: titleController,
              hintText: 'Note Title',
              labelText: 'Title',
            ),
            const AppGap.v16(),
            AppTextField.multiline(
              controller: bodyController,
              hintText: 'Type your secret note here...',
              labelText: 'Body',
              minLines: 5,
            ),
            const AppGap.v24(),
            AppButton.primary(
              text: 'Save Changes',
              onPressed: () async {
                final title = titleController.text.trim();
                final body = bodyController.text.trim();
                if (title.isNotEmpty || body.isNotEmpty) {
                  final updatedNote = note.copyWith(
                    title: title,
                    body: body,
                  );
                  await controller.updateNote(updatedNote);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            const AppGap.v12(),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String id) {
    controller.onUserInteraction();
    AppDialog.delete(
      context,
      title: 'Delete Secret Note',
      message: 'Are you sure you want to permanently delete this secret note? This cannot be undone.',
      deleteLabel: 'Delete',
      cancelLabel: 'Cancel',
      onDelete: () async {
        await controller.deleteNote(id);
      },
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')} '
        '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
  }
}
