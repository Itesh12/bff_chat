import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/notes_repository.dart';

class NotesSearchController extends GetxController {
  final NotesRepository _repository;

  NotesSearchController(this._repository);

  final RxString query = ''.obs;
  final RxList<NoteEntity> results = <NoteEntity>[].obs;
  final RxBool isSearching = false.obs;

  /// Hook for Phase 3 secret keyword detection (completely decoupled)
  VoidCallback? onQuerySubmitted;
  Worker? _searchWorker;

  @override
  void onInit() {
    super.onInit();
    // Enforce 2+ character rule and 300ms debounce
    _searchWorker = debounce<String>(
      query,
      (val) {
        if (val.trim().length >= 2) {
          _executeSearch(val.trim());
        } else {
          results.clear();
        }
      },
      time: const Duration(milliseconds: 300),
    );
  }

  @override
  void onClose() {
    _searchWorker?.dispose();
    super.onClose();
  }

  void onQueryChanged(String value) {
    query.value = value;
  }

  void submitQuery(String value) {
    query.value = value;
    onQuerySubmitted?.call(); // Triggers Phase 3 stealth checks
    if (value.trim().length >= 2) {
      _executeSearch(value.trim());
    } else {
      results.clear();
    }
  }

  Future<void> _executeSearch(String val) async {
    isSearching.value = true;
    try {
      final searchResults = await _repository.searchNotes(val);
      results.assignAll(searchResults);
    } catch (_) {
      results.clear();
    } finally {
      isSearching.value = false;
    }
  }
}
