import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/core/widgets/note_card.dart';
import 'package:memovault/core/widgets/empty_state_widget.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';

class NotesArchiveScreen extends StatefulWidget {
  const NotesArchiveScreen({super.key});

  @override
  State<NotesArchiveScreen> createState() => _NotesArchiveScreenState();
}

class _NotesArchiveScreenState extends State<NotesArchiveScreen> {
  final NotesController _notesController = Get.find<NotesController>();
  final NotesRepository _notesRepository = Get.find<NotesRepository>();

  List<NoteEntity> _archivedNotes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadArchivedNotes();
  }

  Future<void> _loadArchivedNotes() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await _notesRepository.getArchivedNotes();
      setState(() {
        _archivedNotes = list;
      });
    } catch (_) {
      setState(() {
        _archivedNotes = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreNote(String id) async {
    await _notesController.restoreNote(id);
    await _loadArchivedNotes();
    Get.snackbar('Restored', 'Note returned to your dashboard.');
  }

  Future<void> _deleteNotePermanently(String id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text('This action is irreversible. The note contents will be permanently purged from the secure database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _notesController.permanentlyDeleteNote(id);
              await _loadArchivedNotes();
              Get.snackbar('Purged', 'Note permanently deleted.');
            },
            child: const Text('Purge', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive & Trash'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _archivedNotes.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.archive_outlined,
                  title: 'Archive is Empty',
                  message: 'Archived notes or soft-deleted items will appear here for secure storage or purging.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _archivedNotes.length,
                  itemBuilder: (context, index) {
                    final note = _archivedNotes[index];
                    final cat = _notesController.categories.firstWhereOrNull((c) => c.id == note.categoryId);

                    return Dismissible(
                      key: ValueKey(note.id),
                      background: Container(
                        color: Colors.green.withOpacity(0.8),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.unarchive, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red.withOpacity(0.8),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete_forever, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Swipe right to restore
                          await _restoreNote(note.id);
                          return true;
                        } else {
                          // Swipe left to permanently delete
                          await _deleteNotePermanently(note.id);
                          return false; // we handled deletion via confirm dialog, so don't dismiss immediately
                        }
                      },
                      child: NoteCard(
                        note: note,
                        category: cat,
                        isGrid: false,
                        onTap: () {
                          // Allow read-only viewing of archived notes
                          Get.to(() => Scaffold(
                                appBar: AppBar(
                                  title: const Text('Archived Note'),
                                  actions: [
                                    IconButton(
                                      icon: const Icon(Icons.unarchive),
                                      onPressed: () async {
                                        await _restoreNote(note.id);
                                        Get.back();
                                      },
                                    ),
                                  ],
                                ),
                                body: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        note.title.isEmpty ? 'Untitled' : note.title,
                                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(),
                                      const SizedBox(height: 16),
                                      Text(
                                        note.body.isEmpty ? 'No content' : note.body,
                                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ));
                        },
                        onFavoriteTap: () {}, // Favorite disabled in archive
                      ),
                    );
                  },
                ),
    );
  }
}
