/// A tour's playback history. Use a new tour ID to introduce a new tour.
class IntroHistory {
  const IntroHistory({
    this.playCount = 0,
    this.lastPlayedAt,
    this.completed = false,
  });
  final int playCount;
  final DateTime? lastPlayedAt;
  final bool completed;
  Map<String, Object?> toJson() => {
    'playCount': playCount,
    'lastPlayedAt': lastPlayedAt?.toUtc().toIso8601String(),
    'completed': completed,
  };
  factory IntroHistory.fromJson(Map<String, dynamic> json) => IntroHistory(
    playCount: (json['playCount'] as num?)?.toInt() ?? 0,
    lastPlayedAt: DateTime.tryParse(json['lastPlayedAt'] as String? ?? ''),
    completed: json['completed'] as bool? ?? false,
  );
}

/// Implement with local preferences/database for history across app restarts.
abstract interface class IntroHistoryStore {
  Future<IntroHistory?> read(String tourId);
  Future<void> write(String tourId, IntroHistory history);
  Future<void> delete(String tourId);
}

/// Default process-local history. The package performs no network requests.
class MemoryIntroHistoryStore implements IntroHistoryStore {
  static final shared = MemoryIntroHistoryStore();
  final Map<String, IntroHistory> _history = {};
  @override
  Future<IntroHistory?> read(String tourId) async => _history[tourId];
  @override
  Future<void> write(String tourId, IntroHistory history) async {
    _history[tourId] = history;
  }

  @override
  Future<void> delete(String tourId) async {
    _history.remove(tourId);
  }
}

/// Adapts existing storage without adding a storage plugin dependency.
class CallbackIntroHistoryStore implements IntroHistoryStore {
  const CallbackIntroHistoryStore({
    required this.onRead,
    required this.onWrite,
    required this.onDelete,
  });
  final Future<IntroHistory?> Function(String) onRead;
  final Future<void> Function(String, IntroHistory) onWrite;
  final Future<void> Function(String) onDelete;
  @override
  Future<IntroHistory?> read(String tourId) => onRead(tourId);
  @override
  Future<void> write(String tourId, IntroHistory history) =>
      onWrite(tourId, history);
  @override
  Future<void> delete(String tourId) => onDelete(tourId);
}
