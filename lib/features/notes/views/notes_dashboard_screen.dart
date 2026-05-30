import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/services/notes_preferences_service.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';
import 'package:memovault/core/widgets/note_card.dart';
import 'package:memovault/core/widgets/empty_state_widget.dart';
import 'package:memovault/core/widgets/search_bar_widget.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';

class NotesDashboardScreen extends GetView<NotesController> {
  const NotesDashboardScreen({super.key});

  void _showSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Obx(() {
          final currentSort = controller.sortMode.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Sort Notes By',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...NoteSortMode.values.map((mode) {
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
                  return ListTile(
                    leading: Icon(icon, color: isSelected ? theme.primaryColor : null),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.primaryColor : null,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check, color: theme.primaryColor) : null,
                    onTap: () {
                      controller.setSortMode(mode);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final appBar = AppBar(
      title: const Text(
        'MemoVault',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            // Placeholder: Navigate to settings or custom category screen
            Get.toNamed('/notes/categories');
          },
        ),
        IconButton(
          icon: const Icon(Icons.archive),
          onPressed: () {
            Get.toNamed('/notes/archive');
          },
        ),
        Obx(() {
          final isGrid = controller.viewMode.value == NotesViewMode.grid;
          return IconButton(
            icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
            onPressed: () => controller.toggleViewMode(),
          );
        }),
      ],
    );

    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          // 1. Top Search Bar Trigger
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBarWidget(
              readOnly: true,
              onTap: () => Get.toNamed('/notes/search'),
            ),
          ),

          // 2. Category Selector Pills
          Obx(() {
            final activeCat = controller.selectedCategoryId.value;
            final categoriesList = controller.categories;
            
            return SizedBox(
              height: 48,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categoriesList.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = activeCat == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        selected: isSelected,
                        label: const Text('All Notes'),
                        onSelected: (_) => controller.setSelectedCategory(null),
                      ),
                    );
                  }
                  
                  final cat = categoriesList[index - 1];
                  final isSelected = activeCat == cat.id;
                  final color = Color(int.parse('FF${cat.colorHex}', radix: 16));

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: color,
                      ),
                      label: Text(cat.name),
                      selectedColor: color.withOpacity(0.15),
                      checkmarkColor: color,
                      onSelected: (_) => controller.setSelectedCategory(cat.id),
                    ),
                  );
                },
              ),
            );
          }),

          // 3. Sub-header with Note Count and Sorting Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(() {
                  final total = controller.filteredNotes.length;
                  return Text(
                    '$total ${total == 1 ? 'note' : 'notes'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                    ),
                  );
                }),
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: () => _showSortBottomSheet(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // 4. Main list / grid of Notes using Builder-based rendering
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final displayNotes = controller.filteredNotes;
              if (displayNotes.isEmpty) {
                return EmptyStateWidget(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed('/notes/editor'),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }
}
