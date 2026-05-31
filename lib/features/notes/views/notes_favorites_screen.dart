import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';
import 'package:memovault/core/widgets/notes_list_layout.dart';

// Hidden Vault imports
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';

class NotesFavoritesScreen extends StatefulWidget {
  final bool isHiddenMode;
  const NotesFavoritesScreen({super.key, this.isHiddenMode = false});

  @override
  State<NotesFavoritesScreen> createState() => _NotesFavoritesScreenState();
}

class _NotesFavoritesScreenState extends State<NotesFavoritesScreen> {
  NotesController? get _publicController => widget.isHiddenMode ? null : Get.find<NotesController>();
  NotesRepository? get _publicRepo => widget.isHiddenMode ? null : Get.find<NotesRepository>();

  HiddenHomeController? get _hiddenController => widget.isHiddenMode ? Get.find<HiddenHomeController>() : null;
  HiddenNotesRepository? get _hiddenRepo => widget.isHiddenMode ? Get.find<HiddenNotesRepository>() : null;

  @override
  Widget build(BuildContext context) {
    final categories = widget.isHiddenMode
        ? _hiddenController!.categories.toList()
        : _publicController!.categories.toList();

    if (widget.isHiddenMode) {
      return StreamBuilder<List<HiddenNoteEntity>>(
        stream: _hiddenRepo!.watchFavoriteNotes(),
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final rawNotes = snapshot.data ?? [];
          final notes = rawNotes.map((e) => e.toNoteEntity()).toList();

          return NotesListLayout(
            title: 'Secret Favorites',
            notes: notes,
            categories: categories,
            isLoading: isLoading,
            emptyStateIcon: Icons.star_border_rounded,
            emptyStateTitle: 'No Favorites Yet',
            emptyStateMessage: 'Star important secret notes to pin them in your favorites for quick access.',
            enableSwipes: false,
            onUserInteraction: _hiddenController!.onUserInteraction,
            onTapNote: (note) {
              Get.toNamed(AppRoutes.hiddenEditor, arguments: note.id);
            },
            onFavoriteTap: (note) => _hiddenController!.toggleFavorite(note.id),
          );
        },
      );
    } else {
      return StreamBuilder<List<NoteEntity>>(
        stream: _publicRepo!.watchFavoriteNotes(),
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final notes = snapshot.data ?? [];

          return NotesListLayout(
            title: 'Favorites',
            notes: notes,
            categories: categories,
            isLoading: isLoading,
            emptyStateIcon: Icons.star_border_rounded,
            emptyStateTitle: 'No Favorites Yet',
            emptyStateMessage: 'Star important notes to pin them in your favorites for quick access.',
            enableSwipes: false,
            onTapNote: (note) {
              _publicController!.viewNoteDetail(note.id);
              Get.toNamed('/notes/detail/${note.id}');
            },
            onFavoriteTap: (note) => _publicController!.toggleFavorite(note.id),
          );
        },
      );
    }
  }
}
