import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/widgets/note_card.dart';
import 'package:memovault/core/widgets/empty_state_widget.dart';
import 'package:memovault/core/widgets/search_bar_widget.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';
import 'package:memovault/features/notes/controllers/notes_search_controller.dart';

class NotesSearchScreen extends StatefulWidget {
  const NotesSearchScreen({super.key});

  @override
  State<NotesSearchScreen> createState() => _NotesSearchScreenState();
}

class _NotesSearchScreenState extends State<NotesSearchScreen> {
  final NotesSearchController searchController = Get.find<NotesSearchController>();
  final NotesController notesController = Get.find<NotesController>();

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus keyboard on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Notes'),
      ),
      body: Column(
        children: [
          // Dynamic Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SearchBarWidget(
              controller: _textController,
              focusNode: _focusNode,
              hintText: 'Type at least 2 characters...',
              onChanged: searchController.onQueryChanged,
              onSubmitted: searchController.submitQuery,
            ),
          ),

          // Real-time debounced search results list
          Expanded(
            child: Obx(() {
              final query = searchController.query.value.trim();
              final isSearching = searchController.isSearching.value;
              final results = searchController.results;

              if (query.length < 2) {
                return const EmptyStateWidget(
                  icon: Icons.search,
                  title: 'Search in MemoVault',
                  message: 'Enter 2 or more characters to scan title and body contents.',
                );
              }

              if (isSearching) {
                return const Center(child: CircularProgressIndicator());
              }

              if (results.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.find_in_page_outlined,
                  title: 'No Results Match',
                  message: 'No notes match the query "$query". Try searching for different keywords.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final note = results[index];
                  final cat = notesController.categories.firstWhereOrNull((c) => c.id == note.categoryId);
                  
                  return NoteCard(
                    key: ValueKey(note.id),
                    note: note,
                    category: cat,
                    isGrid: false,
                    onTap: () {
                      notesController.viewNoteDetail(note.id); // updates lastOpenedAt + logsOpened
                      Get.toNamed('/notes/detail/${note.id}');
                    },
                    onFavoriteTap: () => notesController.toggleFavorite(note.id),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
