import 'dart:async';
import 'package:get/get.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';

class HiddenHomeController extends GetxController {
  final HiddenNotesRepository _notesRepository;
  final HiddenSessionService _sessionService;

  HiddenHomeController(this._notesRepository, this._sessionService);

  final RxList<HiddenNoteEntity> notes = <HiddenNoteEntity>[].obs;
  StreamSubscription<List<HiddenNoteEntity>>? _notesSubscription;

  @override
  void onInit() {
    super.onInit();
    _notesSubscription = _notesRepository.watchAllNotes().listen((data) {
      notes.assignAll(data);
    });
  }

  @override
  void onClose() {
    _notesSubscription?.cancel();
    super.onClose();
  }

  /// Resets the inactivity timer on any user interaction in the hidden vault.
  void onUserInteraction() {
    _sessionService.resetInactivityTimer();
  }

  Future<void> createNote(String title, String body) async {
    onUserInteraction();
    await _notesRepository.createNote(title: title, body: body);
  }

  Future<void> updateNote(HiddenNoteEntity note) async {
    onUserInteraction();
    await _notesRepository.updateNote(note);
  }

  Future<void> toggleFavorite(String id) async {
    onUserInteraction();
    await _notesRepository.toggleFavorite(id);
  }

  Future<void> deleteNote(String id) async {
    onUserInteraction();
    await _notesRepository.permanentlyDeleteNote(id);
  }

  void logout() {
    _sessionService.lockSession();
    Get.offAllNamed('/home');
  }
}
