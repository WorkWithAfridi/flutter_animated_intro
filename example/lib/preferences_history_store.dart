import 'dart:convert';
import 'package:flutter_animated_intro_flow/flutter_animated_intro_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-owned offline persistence; the package itself needs only Flutter.
class PreferencesHistoryStore implements IntroHistoryStore {
  PreferencesHistoryStore(this.preferences);
  final SharedPreferences preferences;
  String _key(String id) => 'intro_flow_demo.$id';
  @override
  Future<IntroHistory?> read(String tourId) async {
    final raw = preferences.getString(_key(tourId));
    if (raw == null) return null;
    return IntroHistory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(String tourId, IntroHistory history) async {
    if (!await preferences.setString(
      _key(tourId),
      jsonEncode(history.toJson()),
    )) {
      throw StateError('Unable to save intro history.');
    }
  }

  @override
  Future<void> delete(String tourId) async {
    if (!await preferences.remove(_key(tourId))) {
      throw StateError('Unable to reset intro history.');
    }
  }
}
