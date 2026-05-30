import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';

class HiddenSearchScreen extends StatefulWidget {
  const HiddenSearchScreen({super.key});

  @override
  State<HiddenSearchScreen> createState() => _HiddenSearchScreenState();
}

class _HiddenSearchScreenState extends State<HiddenSearchScreen> {
  final HiddenHomeController _controller = Get.find<HiddenHomeController>();

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _query = '';
  List<HiddenNoteEntity> _results = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _controller.onUserInteraction();
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final clean = query.trim();
      setState(() {
        _query = clean;
      });
      _performSearch(clean);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final list = await _controller.searchNotes(query);
      setState(() {
        _results = list;
      });
    } catch (_) {
      setState(() {
        _results = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _controller.onUserInteraction,
      onPanDown: (_) => _controller.onUserInteraction(),
      child: AppScaffold(
        title: 'Search Secret Vault',
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
              child: AppTextField.search(
                controller: _textController,
                focusNode: _focusNode,
                hintText: 'Type at least 2 characters...',
                onChanged: _onQueryChanged,
              ),
            ),
            Expanded(
              child: _query.length < 2
                  ? const AppEmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Search in Secret Vault',
                      message: 'Enter 2 or more characters to scan secret title and body contents.',
                    )
                  : _isSearching
                      ? const Center(child: AppLoading.medium())
                      : _results.isEmpty
                          ? AppEmptyState(
                              icon: Icons.find_in_page_outlined,
                              title: 'No Results Match',
                              message: 'No secret notes match the query "$_query". Try searching for different keywords.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final note = _results[index];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                                  child: AppCard(
                                    onTap: () {
                                      _controller.onUserInteraction();
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
                                              icon: note.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                              color: note.isFavorite ? Colors.amber : null,
                                              onPressed: () async {
                                                await _controller.toggleFavorite(note.id);
                                                await _performSearch(_query);
                                              },
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
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
