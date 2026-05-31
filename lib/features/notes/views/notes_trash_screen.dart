import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';
import 'package:memovault/core/widgets/notes_list_layout.dart';

// Hidden Vault imports
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';

class NotesTrashScreen extends StatefulWidget {
  final bool isHiddenMode;
  const NotesTrashScreen({super.key, this.isHiddenMode = false});

  @override
  State<NotesTrashScreen> createState() => _NotesTrashScreenState();
}

class _NotesTrashScreenState extends State<NotesTrashScreen> {
  List<NoteEntity> _notes = [];
  bool _isLoading = false;

  NotesController? get _publicController => widget.isHiddenMode ? null : Get.find<NotesController>();
  NotesRepository? get _publicRepo => widget.isHiddenMode ? null : Get.find<NotesRepository>();

  HiddenHomeController? get _hiddenController => widget.isHiddenMode ? Get.find<HiddenHomeController>() : null;
  HiddenNotesRepository? get _hiddenRepo => widget.isHiddenMode ? Get.find<HiddenNotesRepository>() : null;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (widget.isHiddenMode) {
        final raw = await _hiddenRepo!.getTrashedNotes();
        _notes = raw.map((e) => e.toNoteEntity()).toList();
      } else {
        _notes = await _publicRepo!.getTrashedNotes();
      }
    } catch (_) {
      _notes = [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreNote(String id) async {
    if (widget.isHiddenMode) {
      await _hiddenController!.restoreNote(id);
    } else {
      await _publicController!.restoreNote(id);
    }
    await _loadNotes();
  }

  Future<void> _deleteNotePermanently(String id) async {
    AppDialog.delete(
      context,
      title: 'Delete Permanently?',
      message: widget.isHiddenMode
          ? 'This secret note will be permanently purged from the secure SQLCipher database. This action is irreversible.'
          : 'This action is irreversible. The note contents will be permanently purged from the secure database.',
      onDelete: () async {
        if (widget.isHiddenMode) {
          await _hiddenController!.permanentlyDeleteNote(id);
        } else {
          await _publicController!.permanentlyDeleteNote(id);
        }
        await _loadNotes();
      },
    );
  }

  Future<void> _emptyTrash() async {
    AppDialog.delete(
      context,
      title: widget.isHiddenMode ? 'Empty Vault Trash?' : 'Empty Trash?',
      message: widget.isHiddenMode
          ? 'Are you sure you want to permanently delete all items in the Vault Trash? This action is irreversible.'
          : 'Are you sure you want to permanently delete all items in the Trash? This action is irreversible.',
      deleteLabel: 'Empty Trash',
      onDelete: () async {
        if (widget.isHiddenMode) {
          await _hiddenController!.emptyTrash();
        } else {
          await _publicController!.emptyTrash();
        }
        await _loadNotes();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.isHiddenMode
        ? _hiddenController!.categories.toList()
        : _publicController!.categories.toList();

    return NotesListLayout(
      title: widget.isHiddenMode ? 'Secret Trash' : 'Trash',
      notes: _notes,
      categories: categories,
      isLoading: _isLoading,
      emptyStateIcon: Icons.delete_outline,
      emptyStateTitle: 'Trash is Empty',
      emptyStateMessage: widget.isHiddenMode
          ? 'Trashed secret notes will appear here. They are securely isolated and fully encrypted.'
          : 'Trashed notes will appear here. You can restore them or permanently delete them.',
      showEmptyTrashAction: true,
      onEmptyTrash: _emptyTrash,
      enableSwipes: true,
      swipeRightIcon: Icons.restore,
      swipeLeftIcon: Icons.delete_forever,
      onSwipeRight: _restoreNote,
      onSwipeLeft: _deleteNotePermanently,
      onUserInteraction: widget.isHiddenMode ? _hiddenController!.onUserInteraction : null,
      onTapNote: (note) {
        if (widget.isHiddenMode) {
          Get.toNamed(AppRoutes.hiddenEditor, arguments: note.id);
        } else {
          Get.toNamed('/notes/detail/${note.id}');
        }
      },
      onFavoriteTap: null, // Favorite disabled in trash
    );
  }
}
