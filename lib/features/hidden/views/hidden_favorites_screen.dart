import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';

class HiddenFavoritesScreen extends StatefulWidget {
  const HiddenFavoritesScreen({super.key});

  @override
  State<HiddenFavoritesScreen> createState() => _HiddenFavoritesScreenState();
}

class _HiddenFavoritesScreenState extends State<HiddenFavoritesScreen> {
  final HiddenHomeController _controller = Get.find<HiddenHomeController>();
  final HiddenNotesRepository _notesRepository = Get.find<HiddenNotesRepository>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _controller.onUserInteraction,
      onPanDown: (_) => _controller.onUserInteraction(),
      child: AppScaffold(
        title: 'Secret Favorites',
        body: StreamBuilder<List<HiddenNoteEntity>>(
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
                message: 'Star important secret notes to pin them in your favorites for quick access.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final note = favorites[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                  child: AppCard(
                    onTap: () {
                      _controller.onUserInteraction();
                      // Show detail bottom sheet read-only or dialog
                      Get.to(() => AppScaffold(
                            title: 'Secret Note Details',
                            body: SingleChildScrollView(
                              padding: const EdgeInsets.all(AppSpacing.s24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note.title.isEmpty ? 'Untitled' : note.title,
                                    style: AppTypography.displayLarge.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const AppGap.v16(),
                                  Container(height: 1, color: theme.dividerColor),
                                  const AppGap.v16(),
                                  Text(
                                    note.body.isEmpty ? 'No content' : note.body,
                                    style: AppTypography.bodyLarge.copyWith(height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ));
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                note.title.isEmpty ? 'Untitled Note' : note.title,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AppIconButton.primary(
                              icon: Icons.star_rounded,
                              color: Colors.amber,
                              onPressed: () => _controller.toggleFavorite(note.id),
                            ),
                          ],
                        ),
                        const AppGap.v8(),
                        Text(
                          note.body,
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
