import 'package:get/get.dart';

class ActivationTriggerService extends GetxService {
  static final _pattern = RegExp(r'^\.[0-9]{4}$');

  /// Returns true if the query is an exact match for the hidden vault trigger pattern (e.g., .4837).
  bool isActivationTrigger(String query) {
    return query == query.trim() && _pattern.hasMatch(query);
  }

  /// Extracts the PIN digits (everything after the leading dot) if query matches, otherwise returns null.
  String? extractPin(String query) {
    if (!isActivationTrigger(query)) return null;
    return query.substring(1);
  }
}
