/// A tour's playback history. Use a new tour ID to introduce a new tour.
class IntroHistory {
  const IntroHistory({
    this.playCount = 0,
    this.lastPlayedAt,
    this.completed = false,
  });

  /// Number of starts recorded, regardless of completion or skipping.
  final int playCount;

  /// Most recent start time, used to evaluate cooldown eligibility.
  final DateTime? lastPlayedAt;

  /// Whether any run of this tour has completed successfully.
  final bool completed;

  /// Encodes timestamps in UTC so local timezone changes do not alter history.
  Map<String, Object?> toJson() => {
    'playCount': playCount,
    'lastPlayedAt': lastPlayedAt?.toUtc().toIso8601String(),
    'completed': completed,
  };

  /// Restores history, defaulting absent fields for older stored records.
  factory IntroHistory.fromJson(Map<String, dynamic> json) => IntroHistory(
    playCount: (json['playCount'] as num?)?.toInt() ?? 0,
    lastPlayedAt: DateTime.tryParse(json['lastPlayedAt'] as String? ?? ''),
    completed: json['completed'] as bool? ?? false,
  );
}

/// Implement with local preferences/database for history across app restarts.
abstract interface class IntroHistoryStore {
  /// Returns null when no record exists for this tour.
  Future<IntroHistory?> read(String tourId);

  /// Saves a full record. Failures should throw so the controller can report them.
  Future<void> write(String tourId, IntroHistory history);

  /// Removes this tour only, allowing it to become eligible again.
  Future<void> delete(String tourId);
}

/// Default process-local history. The package performs no network requests.
class MemoryIntroHistoryStore implements IntroHistoryStore {
  /// Default store shared by controllers for the lifetime of this process.
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

  /// Reads history using the host application's storage mechanism.
  final Future<IntroHistory?> Function(String) onRead;

  /// Persists the complete record under its tour ID.
  final Future<void> Function(String, IntroHistory) onWrite;

  /// Deletes the matching tour record without clearing unrelated app data.
  final Future<void> Function(String) onDelete;
  @override
  Future<IntroHistory?> read(String tourId) => onRead(tourId);
  @override
  Future<void> write(String tourId, IntroHistory history) =>
      onWrite(tourId, history);
  @override
  Future<void> delete(String tourId) => onDelete(tourId);
}
