import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/routes/app_routes.dart';
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
            icon: Icons.search_rounded,
            tooltip: 'Search Vault',
            onPressed: () {
              controller.onUserInteraction();
              Get.toNamed(AppRoutes.hiddenSearch);
            },
          ),
          const AppGap.h8(),
          AppIconButton.secondary(
            icon: Icons.star_border_rounded,
            tooltip: 'Secret Favorites',
            onPressed: () {
              controller.onUserInteraction();
              Get.toNamed(AppRoutes.hiddenFavorites);
            },
          ),
          const AppGap.h8(),
          AppIconButton.secondary(
            icon: Icons.archive_outlined,
            tooltip: 'Secret Archive',
            onPressed: () {
              controller.onUserInteraction();
              Get.toNamed(AppRoutes.hiddenArchive);
            },
          ),
          const AppGap.h8(),
          AppIconButton.secondary(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Secret Trash',
            onPressed: () {
              controller.onUserInteraction();
              Get.toNamed(AppRoutes.hiddenTrash);
            },
          ),
          const AppGap.h8(),
          AppIconButton.secondary(
            icon: Icons.logout_rounded,
            tooltip: 'Lock Vault',
            onPressed: controller.logout,
          ),
          const AppGap.h16(),
        ],
        body: Obx(() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats bar
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s4),
                child: Row(
                  children: [
                    _buildStatChip(
                      context,
                      label: 'Notes',
                      count: controller.notesCount.value,
                      color: theme.primaryColor,
                      icon: Icons.note_alt_outlined,
                    ),
                    const AppGap.h8(),
                    _buildStatChip(
                      context,
                      label: 'Starred',
                      count: controller.favoritesCount.value,
                      color: Colors.amber,
                      icon: Icons.star_border_rounded,
                    ),
                    const AppGap.h8(),
                    _buildStatChip(
                      context,
                      label: 'Archived',
                      count: controller.archivedCount.value,
                      color: Colors.teal,
                      icon: Icons.archive_outlined,
                    ),
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: controller.notes.isEmpty
                    ? AppEmptyState(
                        icon: Icons.lock_outline_rounded,
                        title: 'Private Vault is Empty',
                        message: 'Notes added here are fully encrypted with SQLCipher and are completely isolated from standard notes.',
                        ctaLabel: 'Add Secret Note',
                        onCtaTap: () => _showAddNoteBottomSheet(context),
                      )
                    : ListView.builder(
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
                      ),
              ),
            ],
          );
        }),
        floatingActionButton: Obx(() {
          if (controller.notes.isEmpty) {
            return const SizedBox.shrink();
          }
          return AppButton.primary(
            text: 'New Note',
            icon: Icons.add,
            onPressed: () => _showAddNoteBottomSheet(context),
          );
        }),
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
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s8,
            right: AppSpacing.s8,
            top: AppSpacing.s8,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s8,
          ),
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
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s8,
            right: AppSpacing.s8,
            top: AppSpacing.s8,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s8,
          ),
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
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String id) {
    controller.onUserInteraction();
    AppDialog.delete(
      context,
      title: 'Delete Secret Note',
      message: 'Are you sure you want to delete this secret note? It will be moved to the vault trash.',
      deleteLabel: 'Delete',
      cancelLabel: 'Cancel',
      onDelete: () async {
        await controller.softDeleteNote(id);
      },
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')} '
        '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatChip(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.small,
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const AppGap.h8(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count.toString(),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
