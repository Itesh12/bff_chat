import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/services/notes_preferences_service.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';
import 'package:memovault/core/widgets/note_card.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';

class NotesDashboardScreen extends GetView<NotesController> {
  const NotesDashboardScreen({super.key});

  void _showSortBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    AppBottomSheet.show(
      context,
      title: 'Sort Notes By',
      child: Obx(() {
        final currentSort = controller.sortMode.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: NoteSortMode.values.map((mode) {
            String label = '';
            IconData icon = Icons.sort;
            switch (mode) {
              case NoteSortMode.updatedDesc:
                label = 'Recently edited first';
                icon = Icons.edit_calendar;
                break;
              case NoteSortMode.updatedAsc:
                label = 'Oldest edited first';
                icon = Icons.history;
                break;
              case NoteSortMode.createdDesc:
                label = 'Recently created first';
                icon = Icons.calendar_today;
                break;
              case NoteSortMode.createdAsc:
                label = 'Oldest created first';
                icon = Icons.calendar_month;
                break;
              case NoteSortMode.titleAZ:
                label = 'Title: A to Z';
                icon = Icons.sort_by_alpha;
                break;
              case NoteSortMode.titleZA:
                label = 'Title: Z to A';
                icon = Icons.sort_by_alpha_outlined;
                break;
            }

            final isSelected = currentSort == mode;
            return AppCard(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
              backgroundColor: isSelected ? theme.primaryColor.withValues(alpha: 0.1) : null,
              borderColor: isSelected ? theme.primaryColor.withValues(alpha: 0.3) : null,
              onTap: () {
                controller.setSortMode(mode);
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? theme.primaryColor : theme.iconTheme.color?.withValues(alpha: 0.6),
                  ),
                  const AppGap.h16(),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check, color: theme.primaryColor),
                ],
              ),
            );
          }).toList(),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'MemoVault',
      actions: [
        AppIconButton.secondary(
          icon: Icons.settings,
          tooltip: 'Manage Categories',
          onPressed: () => Get.toNamed('/notes/categories'),
        ),
        const AppGap.h8(),
        AppIconButton.secondary(
          icon: Icons.archive,
          tooltip: 'Archived Notes',
          onPressed: () => Get.toNamed('/notes/archive'),
        ),
        const AppGap.h8(),
        Obx(() {
          final isGrid = controller.viewMode.value == NotesViewMode.grid;
          return AppIconButton.secondary(
            icon: isGrid ? Icons.view_list : Icons.grid_view,
            tooltip: isGrid ? 'List View' : 'Grid View',
            onPressed: () => controller.toggleViewMode(),
          );
        }),
        const AppGap.h12(),
      ],
      body: Column(
        children: [
          // 1. Top Search Bar Trigger
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s8),
            child: AppSearchBar(
              readOnly: true,
              onTap: () => Get.toNamed('/notes/search'),
            ),
          ),

          // 2. Category Selector Pills
          Obx(() {
            final activeCat = controller.selectedCategoryId.value;
            final categoriesList = controller.categories;
            
            return Container(
              height: 48,
              color: Colors.transparent,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                scrollDirection: Axis.horizontal,
                itemCount: categoriesList.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = activeCat == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s8),
                      child: Center(
                        child: GestureDetector(
                          onTap: () => controller.setSelectedCategory(null),
                          child: AppChip(
                            label: 'All Notes',
                            color: isSelected ? theme.primaryColor : context.colors.disabled,
                          ),
                        ),
                      ),
                    );
                  }
                  
                  final cat = categoriesList[index - 1];
                  final isSelected = activeCat == cat.id;
                  final color = Color(int.parse('FF${cat.colorHex}', radix: 16));

                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: Center(
                      child: GestureDetector(
                        onTap: () => controller.setSelectedCategory(cat.id),
                        child: AppChip(
                          label: cat.name,
                          color: isSelected ? color : color.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          // 3. Sub-header with Note Count and Sorting Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(() {
                  final total = controller.filteredNotes.length;
                  return Text(
                    '$total ${total == 1 ? 'note' : 'notes'}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    ),
                  );
                }),
                AppIconButton.secondary(
                  icon: Icons.sort,
                  tooltip: 'Sort Options',
                  onPressed: () => _showSortBottomSheet(context),
                ),
              ],
            ),
          ),

          // 4. Main list / grid of Notes using Builder-based rendering
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: AppLoading.medium());
              }

              final displayNotes = controller.filteredNotes;
              if (displayNotes.isEmpty) {
                return AppEmptyState(
                  icon: Icons.note_alt_outlined,
                  title: 'No Notes Found',
                  message: controller.selectedCategoryId.value == null
                      ? 'Create your first note to start securing your thoughts!'
                      : 'No notes in this category yet.',
                  ctaLabel: 'Add Note',
                  onCtaTap: () => Get.toNamed('/notes/editor'),
                );
              }

              final isGrid = controller.viewMode.value == NotesViewMode.grid;

              if (isGrid) {
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: AppSpacing.s8,
                    mainAxisSpacing: AppSpacing.s8,
                  ),
                  itemCount: displayNotes.length,
                  itemBuilder: (context, index) {
                    final note = displayNotes[index];
                    final cat = controller.categories.firstWhereOrNull((c) => c.id == note.categoryId);
                    return NoteCard(
                      key: ValueKey(note.id),
                      note: note,
                      category: cat,
                      isGrid: true,
                      onTap: () {
                        controller.viewNoteDetail(note.id);
                        Get.toNamed('/notes/detail/${note.id}');
                      },
                      onFavoriteTap: () => controller.toggleFavorite(note.id),
                    );
                  },
                );
              } else {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
                  itemCount: displayNotes.length,
                  itemBuilder: (context, index) {
                    final note = displayNotes[index];
                    final cat = controller.categories.firstWhereOrNull((c) => c.id == note.categoryId);
                    return NoteCard(
                      key: ValueKey(note.id),
                      note: note,
                      category: cat,
                      isGrid: false,
                      onTap: () {
                        controller.viewNoteDetail(note.id);
                        Get.toNamed('/notes/detail/${note.id}');
                      },
                      onFavoriteTap: () => controller.toggleFavorite(note.id),
                    );
                  },
                );
              }
            }),
          ),
        ],
      ),
      floatingActionButton: AppButton.primary(
        text: 'New Note',
        icon: Icons.add,
        onPressed: () => Get.toNamed('/notes/editor'),
      ),
    );
  }
}
