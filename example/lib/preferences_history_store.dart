import 'dart:convert';
import 'package:flutter_animated_intro/flutter_animated_intro.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-owned offline persistence; the package itself needs only Flutter.
class PreferencesHistoryStore implements IntroHistoryStore {
  PreferencesHistoryStore(this.preferences);

  /// Preferences loaded during app startup, before the first automatic start.
  final SharedPreferences preferences;
  // Namespace tour records so resetting one tour leaves unrelated settings intact.
  String _key(String id) => 'flutter_animated_intro_demo.$id';
  @override
  Future<IntroHistory?> read(String tourId) async {
    final raw = preferences.getString(_key(tourId));
    if (raw == null) return null;
    return IntroHistory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(String tourId, IntroHistory history) async {
    // Surface plugin write failures instead of silently losing frequency history.
    if (!await preferences.setString(
      _key(tourId),
      jsonEncode(history.toJson()),
    )) {
      throw StateError('Unable to save intro history.');
    }
  }

  @override
  Future<void> delete(String tourId) async {
    // resetHistory propagates failures to its caller, which can show feedback.
    if (!await preferences.remove(_key(tourId))) {
      throw StateError('Unable to reset intro history.');
    }
  }
}
