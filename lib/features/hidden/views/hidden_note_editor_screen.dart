import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/domain/notes/note_metrics.dart';
import 'package:memovault/core/widgets/note_editor_form.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';
import 'package:memovault/core/design_system/design_system.dart';

class HiddenNoteEditorScreen extends StatefulWidget {
  const HiddenNoteEditorScreen({super.key});

  @override
  State<HiddenNoteEditorScreen> createState() => _HiddenNoteEditorScreenState();
}

class _HiddenNoteEditorScreenState extends State<HiddenNoteEditorScreen> {
  final HiddenHomeController _controller = Get.find<HiddenHomeController>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  String? _noteId;
  HiddenNoteEntity? _existingNote;
  String? _selectedCategoryId;

  Timer? _debounceTimer;
  bool _isSaving = false;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.onUserInteraction();
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
      final note = _controller.notes.firstWhereOrNull((n) => n.id == _noteId);
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
    _controller.onUserInteraction();
    setState(() {
      _wordCount = NoteMetrics.calculateWordCount(_bodyController.text);
    });
    _triggerAutoSave();
  }

  void _triggerAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(AppDurations.slow, () {
      _saveNote();
    });
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty && body.isEmpty) {
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_existingNote == null) {
        // Create new hidden note
        final id = _noteId;
        if (id != null) {
          // If we had a pre-generated ID or fallback
        }
        await _controller.createNote(title, body, categoryId: _selectedCategoryId);
        // Find the newly created note to associate with _existingNote to avoid duplicate inserts
        final recentNote = _controller.notes.firstWhereOrNull((n) => n.title == title && n.body == body);
        if (recentNote != null) {
          _existingNote = recentNote;
          _noteId = recentNote.id;
        }
      } else {
        // Update existing hidden note
        final updatedNote = _existingNote!.copyWith(
          title: title,
          body: body,
          categoryId: _selectedCategoryId,
        );
        await _controller.updateNote(updatedNote);
        final refreshedNote = _controller.notes.firstWhereOrNull((n) => n.id == _existingNote!.id);
        if (refreshedNote != null) {
          _existingNote = refreshedNote;
        }
      }
    } catch (e, stack) {
      AppLogger.error('Failed to auto-save secret note', error: e, stackTrace: stack);
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

  void _deleteNote() {
    if (_existingNote != null) {
      AppDialog.delete(
        context,
        title: 'Delete Secret Note',
        message: 'Are you sure you want to delete this secret note? It will be moved to the vault trash.',
        deleteLabel: 'Delete',
        cancelLabel: 'Cancel',
        onDelete: () async {
          _debounceTimer?.cancel();
          await _controller.softDeleteNote(_existingNote!.id);
          if (mounted) {
            // We set existing note to null or just pop so it doesn't trigger autosave during pop
            _existingNote = null;
            Get.back();
          }
        },
      );
    }
  }

  Future<bool> _onWillPop() async {
    _debounceTimer?.cancel();
    if (_existingNote != null) {
      await _saveNote();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _onWillPop();
        }
      },
      child: Obx(() {
        return NoteEditorForm(
          title: _existingNote == null ? 'New Secret Note' : 'Edit Secret Note',
          titleController: _titleController,
          bodyController: _bodyController,
          wordCount: _wordCount,
          revision: _existingNote?.revision,
          isSaving: _isSaving,
          selectedCategoryId: _selectedCategoryId,
          categories: _controller.categories.toList(),
          onCategorySelected: _selectCategory,
          onDelete: _existingNote != null ? _deleteNote : null,
        );
      }),
    );
  }
}
