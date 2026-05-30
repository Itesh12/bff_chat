import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/domain/notes/note_metrics.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final NotesController _notesController = Get.find<NotesController>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  String? _noteId;
  NoteEntity? _existingNote;
  String? _selectedCategoryId;
  
  Timer? _debounceTimer;
  bool _isSaving = false;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _noteId = Get.arguments as String?;
    _initializeNote();
    
    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _initializeNote() {
    if (_noteId != null) {
      // Edit mode: fetch note
      final note = _notesController.notes.firstWhereOrNull((n) => n.id == _noteId);
      if (note != null) {
        _existingNote = note;
        _titleController.text = note.title;
        _bodyController.text = note.body;
        _selectedCategoryId = note.categoryId;
        _wordCount = NoteMetrics.calculateWordCount(note.body);
      }
    }
  }

  void _onTextChanged() {
    setState(() {
      _wordCount = NoteMetrics.calculateWordCount(_bodyController.text);
    });
    _triggerAutoSave();
  }

  void _triggerAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveNote();
    });
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    // If completely empty, do not create a database entry yet
    if (title.isEmpty && body.isEmpty) {
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_existingNote == null) {
        // Create new note
        final newNote = await _notesController.createNote(
          title: title,
          body: body,
          categoryId: _selectedCategoryId,
        );
        _existingNote = newNote;
        _noteId = newNote.id;
        AppLogger.debug('note_autosaved', metadata: {'note_id': 'REDACTED'});
      } else {
        // Update existing note
        final updatedNote = _existingNote!.copyWith(
          title: title,
          body: body,
          categoryId: _selectedCategoryId,
        );
        final result = await _notesController.updateNote(updatedNote);
        _existingNote = result;
        AppLogger.debug('note_autosaved', metadata: {'note_id': 'REDACTED'});
      }
    } catch (e, stack) {
      AppLogger.error('Failed to auto-save note', error: e, stackTrace: stack);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _selectCategory(CategoryEntity? category) {
    setState(() {
      _selectedCategoryId = category?.id;
    });
    _saveNote();
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Assign Category',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.label_off),
                  title: const Text('Uncategorized'),
                  trailing: _selectedCategoryId == null ? const Icon(Icons.check) : null,
                  onTap: () {
                    _selectCategory(null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                Expanded(
                  child: Obx(() {
                    final cats = _notesController.categories;
                    if (cats.isEmpty) {
                      return const Center(
                        child: Text('No categories. Go to Settings to create one.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: cats.length,
                      itemBuilder: (context, index) {
                        final cat = cats[index];
                        final isSelected = _selectedCategoryId == cat.id;
                        final color = Color(int.parse('FF${cat.colorHex}', radix: 16));
                        
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 10,
                            backgroundColor: color,
                          ),
                          title: Text(cat.name),
                          trailing: isSelected ? const Icon(Icons.check) : null,
                          onTap: () {
                            _selectCategory(cat);
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    // Exiting editor: wait for any pending save to complete
    _debounceTimer?.cancel();
    await _saveNote();

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    // If a new note was started but never got any contents, prompt discard or silent exit
    if (_existingNote == null && title.isEmpty && body.isEmpty) {
      return true; // Silence exit, nothing to discard
    }

    return true; // Auto-saved successfully, always allow exit
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final toolbarBg = isDark ? Colors.grey[950]! : Colors.grey[50]!;
    final toolbarBorder = isDark ? Colors.grey[900]! : Colors.grey[200]!;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_existingNote == null ? 'New Note' : 'Edit Note'),
          actions: [
            Obx(() {
              final activeCategory = _notesController.categories
                  .firstWhereOrNull((c) => c.id == _selectedCategoryId);
              final color = activeCategory != null
                  ? Color(int.parse('FF${activeCategory.colorHex}', radix: 16))
                  : Colors.grey;

              return TextButton.icon(
                onPressed: _showCategoryPicker,
                icon: CircleAvatar(
                  radius: 6,
                  backgroundColor: color,
                ),
                label: Text(
                  activeCategory?.name ?? 'Category',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: activeCategory != null ? color : null,
                  ),
                ),
              );
            }),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: _isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: theme.primaryColor.withOpacity(0.6),
                        ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Note Title Input
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: TextField(
                controller: _titleController,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Note Title',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            
            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Divider(color: toolbarBorder),
            ),

            // Note Body Input
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Start writing...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),

            // Bottom Footer Toolbar
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: toolbarBg,
                border: Border(top: BorderSide(color: toolbarBorder, width: 1.0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_wordCount ${_wordCount == 1 ? 'word' : 'words'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    ),
                  ),
                  if (_existingNote != null)
                    Text(
                      'Revision ${_existingNote!.revision}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.primaryColor.withOpacity(0.7),
                        fontWeight: FontWeight.bold,
                      ),
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
