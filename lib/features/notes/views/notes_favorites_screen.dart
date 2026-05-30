import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/core/widgets/note_card.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';

class NotesFavoritesScreen extends StatefulWidget {
  const NotesFavoritesScreen({super.key});

  @override
  State<NotesFavoritesScreen> createState() => _NotesFavoritesScreenState();
}

class _NotesFavoritesScreenState extends State<NotesFavoritesScreen> {
  final NotesController _notesController = Get.find<NotesController>();
  final NotesRepository _notesRepository = Get.find<NotesRepository>();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Favorites',
      body: StreamBuilder<List<NoteEntity>>(
        stream: _notesRepository.watchFavoriteNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AppLoading.medium());
          }
          final favorites = snapshot.data ?? [];

          if (favorites.isEmpty) {
            return const AppEmptyState(
              icon: Icons.star_border_rounded,
              title: 'No Favorites Yet',
              message: 'Star important notes to pin them in your favorites for quick access.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final note = favorites[index];
              final cat = _notesController.categories.firstWhereOrNull((c) => c.id == note.categoryId);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                child: NoteCard(
                  key: ValueKey(note.id),
                  note: note,
                  category: cat,
                  isGrid: false,
                  onTap: () {
                    _notesController.viewNoteDetail(note.id);
                    Get.toNamed('/notes/detail/${note.id}');
                  },
                  onFavoriteTap: () => _notesController.toggleFavorite(note.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
