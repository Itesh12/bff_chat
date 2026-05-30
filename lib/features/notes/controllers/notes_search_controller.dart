import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/core/theme/app_durations.dart';
import 'package:memovault/features/hidden/services/activation_trigger_service.dart';

import 'package:memovault/core/observability/performance_tracker.dart';

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
      time: AppDurations.debounce,
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
    final activationTrigger = Get.find<ActivationTriggerService>();
    if (activationTrigger.isActivationTrigger(value)) {
      // SECURITY: Clear all search state before routing.
      // The trigger string MUST NOT reach AppLogger, AnalyticsService,
      // or any observable that persists beyond this frame.
      query.value = '';
      results.clear();
      isSearching.value = false;
      // Route — no log call before or after
      Get.toNamed(AppRoutes.hiddenPin);
      return;
    }

    query.value = value;
    onQuerySubmitted?.call(); // Triggers Phase 3 stealth checks
    if (value.trim().length >= 2) {
      _executeSearch(value.trim());
    } else {
      results.clear();
    }
  }

  Future<void> _executeSearch(String val) async {
    PerformanceTracker.start('search_notes');
    isSearching.value = true;
    try {
      final searchResults = await _repository.searchNotes(val);
      results.assignAll(searchResults);
      AppLogger.info('note_searched', metadata: {
        'query_length': val.length,
        'results_count': searchResults.length,
      });
    } catch (_) {
      results.clear();
    } finally {
      isSearching.value = false;
      PerformanceTracker.finish('search_notes');
    }
  }
}
