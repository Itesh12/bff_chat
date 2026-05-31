import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/core/widgets/note_search_layout.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';
import 'package:memovault/features/notes/controllers/notes_search_controller.dart';
import 'package:memovault/features/hidden/services/activation_trigger_service.dart';

// Hidden Vault imports
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';

class NotesSearchScreen extends StatefulWidget {
  final bool isHiddenMode;
  const NotesSearchScreen({super.key, this.isHiddenMode = false});

  @override
  State<NotesSearchScreen> createState() => _NotesSearchScreenState();
}

class _NotesSearchScreenState extends State<NotesSearchScreen> {
  // Public Controllers
  NotesSearchController? _publicSearchController;
  NotesController? _publicNotesController;

  // Hidden Controllers
  HiddenHomeController? _hiddenController;

  // Local state for hidden search to keep it isolated
  String _hiddenQuery = '';
  List<NoteEntity> _hiddenResults = [];
  bool _hiddenIsSearching = false;
  Timer? _hiddenDebounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isHiddenMode) {
      _hiddenController = Get.find<HiddenHomeController>();
    } else {
      _publicSearchController = Get.find<NotesSearchController>();
      _publicNotesController = Get.find<NotesController>();
    }
  }

  @override
  void dispose() {
    _hiddenDebounceTimer?.cancel();
    super.dispose();
  }

  void _onHiddenQueryChanged(String query) {
    _hiddenDebounceTimer?.cancel();
    _hiddenDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      final clean = query.trim();
      setState(() {
        _hiddenQuery = clean;
      });
      _performHiddenSearch(clean);
    });
  }

  Future<void> _performHiddenSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _hiddenResults = [];
        _hiddenIsSearching = false;
      });
      return;
    }

    setState(() {
      _hiddenIsSearching = true;
    });

    try {
      final raw = await _hiddenController!.searchNotes(query);
      setState(() {
        _hiddenResults = raw.map((e) => e.toNoteEntity()).toList();
      });
    } catch (_) {
      setState(() {
        _hiddenResults = [];
      });
    } finally {
      setState(() {
        _hiddenIsSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHiddenMode) {
      return NoteSearchLayout(
        title: 'Search Secret Vault',
        isSearching: _hiddenIsSearching,
        query: _hiddenQuery,
        results: _hiddenResults,
        categories: _hiddenController!.categories.toList(),
        onQueryChanged: _onHiddenQueryChanged,
        onTapNote: (note) {
          Get.toNamed(AppRoutes.hiddenEditor, arguments: note.id);
        },
        onFavoriteTap: (note) async {
          await _hiddenController!.toggleFavorite(note.id);
          await _performHiddenSearch(_hiddenQuery);
        },
        onUserInteraction: _hiddenController!.onUserInteraction,
        emptyStateIcon: Icons.lock_outline_rounded,
        emptyStateTitle: 'Search in Secret Vault',
        emptyStateMessage: 'Enter 2 or more characters to scan secret title and body contents.',
      );
    } else {
      return Obx(() {
        final query = _publicSearchController!.query.value;
        final isSearching = _publicSearchController!.isSearching.value;
        final results = _publicSearchController!.results.toList();
        final categories = _publicNotesController!.categories.toList();

        return NoteSearchLayout(
          title: 'Search Notes',
          isSearching: isSearching,
          query: query,
          results: results,
          categories: categories,
          onQueryChanged: _publicSearchController!.onQueryChanged,
          onSubmitted: (value) {
            final activationTrigger = Get.find<ActivationTriggerService>();
            if (activationTrigger.isActivationTrigger(value)) {
              // Trigger checks and navigation are handled by ActivationTriggerService intercepting TextField submission
            }
            _publicSearchController!.submitQuery(value);
          },
          onTapNote: (note) {
            _publicNotesController!.viewNoteDetail(note.id);
            Get.toNamed('/notes/detail/${note.id}');
          },
          onFavoriteTap: (note) => _publicNotesController!.toggleFavorite(note.id),
          emptyStateIcon: Icons.search,
          emptyStateTitle: 'Search in MemoVault',
          emptyStateMessage: 'Enter 2 or more characters to scan title and body contents.',
        );
      });
    }
  }
}
