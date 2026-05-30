import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/domain/notes/note_metrics.dart';
import 'package:memovault/core/design_system/design_system.dart';
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
        final newNote = await _notesController.createNote(
          title: title,
          body: body,
          categoryId: _selectedCategoryId,
        );
        _existingNote = newNote;
        _noteId = newNote.id;
        AppLogger.debug('note_autosaved', metadata: {'note_id': 'REDACTED'});
      } else {
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
    final theme = Theme.of(context);
    AppBottomSheet.show(
      context,
      title: 'Assign Category',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
            onTap: () {
              _selectCategory(null);
              Navigator.pop(context);
            },
            child: Row(
              children: [
                Icon(Icons.label_off, color: theme.iconTheme.color?.withValues(alpha: 0.6)),
                const AppGap.h16(),
                const Expanded(
                  child: Text('Uncategorized', style: AppTypography.bodyMedium),
                ),
                if (_selectedCategoryId == null)
                  Icon(Icons.check, color: theme.primaryColor),
              ],
            ),
          ),
          const AppGap.v8(),
          SizedBox(
            height: 200,
            child: Obx(() {
              final cats = _notesController.categories;
              if (cats.isEmpty) {
                return const Center(
                  child: Text('No categories created yet.'),
                );
              }
              return ListView.builder(
                itemCount: cats.length,
                itemBuilder: (context, index) {
                  final cat = cats[index];
                  final isSelected = _selectedCategoryId == cat.id;
                  final color = Color(int.parse('FF${cat.colorHex}', radix: 16));
                  
                  return AppCard(
                    margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                    onTap: () {
                      _selectCategory(cat);
                      Navigator.pop(context);
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: color,
                        ),
                        const AppGap.h16(),
                        Expanded(
                          child: Text(cat.name, style: AppTypography.bodyMedium),
                        ),
                        if (isSelected)
                          Icon(Icons.check, color: theme.primaryColor),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    _debounceTimer?.cancel();
    await _saveNote();
    return true; 
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final toolbarBg = theme.scaffoldBackgroundColor;
    final toolbarBorder = theme.dividerColor;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _onWillPop();
        }
      },
      child: AppScaffold(
        title: _existingNote == null ? 'New Note' : 'Edit Note',
        actions: [
          Obx(() {
            final activeCategory = _notesController.categories
                .firstWhereOrNull((c) => c.id == _selectedCategoryId);
            final color = activeCategory != null
                ? Color(int.parse('FF${activeCategory.colorHex}', radix: 16))
                : context.colors.disabled;

            return Center(
              child: GestureDetector(
                onTap: _showCategoryPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 6,
                        backgroundColor: color,
                      ),
                      const AppGap.h8(),
                      Text(
                        activeCategory?.name ?? 'Category',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: activeCategory != null ? color : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s16),
              child: SizedBox(
                height: 16,
                width: 16,
                child: _isSaving
                    ? const AppLoading.small()
                    : Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: theme.primaryColor.withValues(alpha: 0.6),
                      ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // Note Title Input
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s4),
              child: AppTextField(
                controller: _titleController,
                hintText: 'Note Title',
                borderless: true,
              ),
            ),
            
            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: Container(height: 1, color: toolbarBorder),
            ),

            // Note Body Input
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: AppTextField.multiline(
                  controller: _bodyController,
                  hintText: 'Start writing...',
                  borderless: true,
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_wordCount ${_wordCount == 1 ? 'word' : 'words'}',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                    ),
                  ),
                  if (_existingNote != null)
                    Text(
                      'Revision ${_existingNote!.revision}',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.primaryColor.withValues(alpha: 0.7),
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
