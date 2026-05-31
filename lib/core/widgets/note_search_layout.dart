import 'package:flutter/material.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/core/widgets/note_card.dart';
import 'package:get/get.dart';
import 'package:memovault/features/hidden/services/activation_trigger_service.dart';

class NoteSearchLayout extends StatefulWidget {
  final String title;
  final String hintText;
  final bool isSearching;
  final String query;
  final List<NoteEntity> results;
  final List<CategoryEntity> categories;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<NoteEntity> onTapNote;
  final ValueChanged<NoteEntity> onFavoriteTap;
  final VoidCallback? onUserInteraction;
  final IconData emptyStateIcon;
  final String emptyStateTitle;
  final String emptyStateMessage;

  const NoteSearchLayout({
    super.key,
    required this.title,
    this.hintText = 'Type at least 2 characters...',
    required this.isSearching,
    required this.query,
    required this.results,
    required this.categories,
    required this.onQueryChanged,
    this.onSubmitted,
    required this.onTapNote,
    required this.onFavoriteTap,
    this.onUserInteraction,
    required this.emptyStateIcon,
    required this.emptyStateTitle,
    required this.emptyStateMessage,
  });

  @override
  State<NoteSearchLayout> createState() => _NoteSearchLayoutState();
}

class _NoteSearchLayoutState extends State<NoteSearchLayout> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant NoteSearchLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _textController.text) {
      _textController.text = widget.query;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          child: AppTextField.search(
            controller: _textController,
            focusNode: _focusNode,
            hintText: widget.hintText,
            onChanged: (val) {
              widget.onUserInteraction?.call();
              widget.onQueryChanged(val);
            },
            onSubmitted: (val) {
              widget.onUserInteraction?.call();
              try {
                final activationTrigger = Get.find<ActivationTriggerService>();
                if (activationTrigger.isActivationTrigger(val)) {
                  _textController.clear();
                  _focusNode.unfocus();
                }
              } catch (_) {}

              if (widget.onSubmitted != null) {
                widget.onSubmitted!(val);
              }
            },
          ),
        ),
        Expanded(
          child: widget.query.trim().length < 2
              ? AppEmptyState(
                  icon: widget.emptyStateIcon,
                  title: widget.emptyStateTitle,
                  message: widget.emptyStateMessage,
                )
              : widget.isSearching
                  ? const Center(child: AppLoading.medium())
                  : widget.results.isEmpty
                      ? AppEmptyState(
                          icon: Icons.find_in_page_outlined,
                          title: 'No Results Match',
                          message: 'No notes match the query "${widget.query}". Try searching for different keywords.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
                          itemCount: widget.results.length,
                          itemBuilder: (context, index) {
                            final note = widget.results[index];
                            final cat = widget.categories.cast<CategoryEntity?>().firstWhere((c) => c?.id == note.categoryId, orElse: () => null);

                            return NoteCard(
                              key: ValueKey(note.id),
                              note: note,
                              category: cat,
                              isGrid: false,
                              onTap: () {
                                _focusNode.unfocus();
                                widget.onUserInteraction?.call();
                                widget.onTapNote(note);
                              },
                              onFavoriteTap: () {
                                widget.onUserInteraction?.call();
                                widget.onFavoriteTap(note);
                              },
                            );
                          },
                        ),
        ),
      ],
    );

    if (widget.onUserInteraction != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onUserInteraction,
        onPanDown: (_) => widget.onUserInteraction!(),
        child: content,
      );
    }

    return AppScaffold(
      title: widget.title,
      body: content,
    );
  }
}
