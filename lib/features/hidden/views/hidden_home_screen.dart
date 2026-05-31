import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/core/widgets/note_card.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';

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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: theme.iconTheme.color?.withValues(alpha: 0.8)),
            onSelected: (value) {
              controller.onUserInteraction();
              switch (value) {
                case 'favorites':
                  Get.toNamed(AppRoutes.hiddenFavorites);
                  break;
                case 'archive':
                  Get.toNamed(AppRoutes.hiddenArchive);
                  break;
                case 'trash':
                  Get.toNamed(AppRoutes.hiddenTrash);
                  break;
                case 'lock':
                  controller.logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'favorites',
                child: Row(
                  children: [
                    Icon(Icons.star_border_rounded, size: 20),
                    AppGap.h8(),
                    Text('Favorites'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, size: 20),
                    AppGap.h8(),
                    Text('Archive'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'trash',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20),
                    AppGap.h8(),
                    Text('Trash'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'lock',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 20, color: Colors.red),
                    AppGap.h8(),
                    Text('Lock Vault', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const AppGap.h16(),
        ],
        body: Obx(() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Unified premium header card
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s16),
                  backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                  borderColor: theme.colorScheme.primary.withValues(alpha: 0.25),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const AppGap.h16(),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Private Vault',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const AppGap.v4(),
                            Text(
                              '${controller.notesCount.value} Notes  ·  ${controller.favoritesCount.value} Starred  ·  ${controller.archivedCount.value} Archived',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Main content
              Expanded(
                child: controller.notes.isEmpty
                    ? AppEmptyState(
                        customIcon: const Text(
                          '🔒',
                          style: TextStyle(fontSize: 40),
                        ),
                        title: 'No Hidden Notes',
                        message: 'Your private notes will appear here.',
                        ctaLabel: 'Create Hidden Note',
                        onCtaTap: () => Get.toNamed(AppRoutes.hiddenEditor),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        itemCount: controller.notes.length,
                        itemBuilder: (context, index) {
                          final note = controller.notes[index];
                          final cat = controller.categories
                              .firstWhereOrNull((c) => c.id == note.categoryId);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                            child: NoteCard(
                              key: ValueKey(note.id),
                              note: note.toNoteEntity(),
                              category: cat,
                              isGrid: false,
                              onTap: () {
                                controller.onUserInteraction();
                                Get.toNamed(AppRoutes.hiddenEditor, arguments: note.id);
                              },
                              onFavoriteTap: () => controller.toggleFavorite(note.id),
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
            onPressed: () => Get.toNamed(AppRoutes.hiddenEditor),
          );
        }),
      ),
    );
  }
}
