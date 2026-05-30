import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';
class NoteDetailScreen extends GetView<NotesController> {
  const NoteDetailScreen({super.key});

  Color _parseCategoryColor(String? hexString) {
    if (hexString == null || hexString.length != 6) {
      return Colors.grey;
    }
    try {
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (_) {
      return Colors.grey;
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
    final isDark = theme.brightness == Brightness.dark;

    final borderThemeColor = isDark ? Colors.grey[850]! : Colors.grey[200]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Note'),
        actions: [
          Obx(() {
            final note = controller.notes.firstWhereOrNull((n) => n.id == id);
            if (note == null) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(
                note.isFavorite ? Icons.star : Icons.star_border,
                color: note.isFavorite ? Colors.amber : null,
              ),
              onPressed: () => controller.toggleFavorite(note.id),
            );
          }),
          Obx(() {
            final note = controller.notes.firstWhereOrNull((n) => n.id == id);
            if (note == null) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.archive_outlined),
              onPressed: () {
                controller.archiveNote(note.id);
                Get.back();
                Get.snackbar('Archived', 'Note moved to archive.');
              },
            );
          }),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              if (id != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Note?'),
                    content: const Text('This will move your note to trash. You can restore it later from archive.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          controller.softDeleteNote(id);
                          Navigator.pop(context);
                          Get.back();
                          Get.snackbar('Deleted', 'Note moved to trash.');
                        },
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Obx(() {
        final note = controller.notes.firstWhereOrNull((n) => n.id == id);
        if (note == null) {
          return const Center(child: Text('Note not found.'));
        }

        final category = controller.categories.firstWhereOrNull((c) => c.id == note.categoryId);
        final categoryColor = _parseCategoryColor(category?.colorHex);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Tag if active
                    if (category != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category.name,
                          style: TextStyle(
                            color: categoryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Note Title
                    SelectableText(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: note.title.isEmpty
                            ? theme.textTheme.headlineMedium?.color?.withOpacity(0.3)
                            : null,
                      ),
                    ),
                    
                    const SizedBox(height: 8),

                    // Timestamp indicator
                    Text(
                      'Last saved: ${_formatDateTime(note.updatedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Note Body Content
                    SelectableText(
                      note.body.isEmpty ? 'No content' : note.body,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: note.body.isEmpty
                            ? theme.textTheme.bodyLarge?.color?.withOpacity(0.3)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Metadata footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderThemeColor, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created: ${_formatDateTime(note.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                      fontSize: 10,
                    ),
                  ),
                  if (note.lastOpenedAt != null)
                    Text(
                      'Last viewed: ${_formatDateTime(note.lastOpenedAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.toNamed('/notes/editor', arguments: id),
        child: const Icon(Icons.edit),
      ),
    );
  }
}
