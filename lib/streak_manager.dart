import 'package:shared_preferences/shared_preferences.dart';

class StreakStatus {
  final int currentStreak;
  final int bestStreak;
  final int todayCount;
  final String todayDate; // yyyy-MM-dd
  final bool todayCompleted;

  StreakStatus({
    required this.currentStreak,
    required this.bestStreak,
    required this.todayCount,
    required this.todayDate,
    required this.todayCompleted,
  });
}

class StreakManager {
  static const _kTodayCountKey = 'streak_today_count';
  static const _kTodayDateKey = 'streak_today_date';
  static const _kLastStreakDateKey = 'streak_last_streak_date';
  static const _kCurrentStreakKey = 'streak_current';
  static const _kBestStreakKey = 'streak_best';

  final int requiredPerDay;
  late SharedPreferences _prefs;

  StreakManager({this.requiredPerDay = 4});


  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String _dateString([DateTime? dt]) {
    final d = dt ?? DateTime.now();
    // usa apenas a parte de data local no formato YYYY-MM-DD
    return d.toLocal().toIso8601String().split('T').first;
  }

  int _getInt(String key, [int defaultValue = 0]) => _prefs.getInt(key) ?? defaultValue;
  String? _getString(String key) => _prefs.getString(key);

  Future<void> _setInt(String key, int value) => _prefs.setInt(key, value);
  Future<void> _setString(String key, String value) => _prefs.setString(key, value);

  StreakStatus getStatus() {
    final todayDateStored = _getString(_kTodayDateKey) ?? '';
    final today = _dateString();
    final todayCount = (todayDateStored == today) ? _getInt(_kTodayCountKey, 0) : 0;
    final lastStreakDate = _getString(_kLastStreakDateKey) ?? '';
    final currentStreak = _getInt(_kCurrentStreakKey, 0);
    final bestStreak = _getInt(_kBestStreakKey, 0);
    final todayCompleted = todayCount >= requiredPerDay && lastStreakDate == today;
    return StreakStatus(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      todayCount: todayCount,
      todayDate: today,
      todayCompleted: todayCompleted,
    );
  }

  Future<StreakStatus> markExerciseDone() async {
    final today = _dateString();
    final storedTodayDate = _getString(_kTodayDateKey);
    int todayCount = 0;
    if (storedTodayDate == today) {
      todayCount = _getInt(_kTodayCountKey, 0);
    } else {
      await _setString(_kTodayDateKey, today);
      await _setInt(_kTodayCountKey, 0);
      todayCount = 0;
    }

    final lastStreakDate = _getString(_kLastStreakDateKey);
    // If we've already counted today for streak, do not increment or double-count.
    if (lastStreakDate == today && todayCount >= requiredPerDay) {
      return getStatus();
    }

    // increment today's counter
    todayCount = (todayCount + 1);
    await _setInt(_kTodayCountKey, todayCount);

    if (todayCount >= requiredPerDay && lastStreakDate != today) {
      await _applyDayCompleted(today, lastStreakDate);
    }

    return getStatus();
  }

  Future<void> _applyDayCompleted(String today, String? lastStreakDate) async {
    final currentStreak = _getInt(_kCurrentStreakKey, 0);
    final bestStreak = _getInt(_kBestStreakKey, 0);

    final yesterday = _dateString(DateTime.now().subtract(Duration(days: 1)));
    int newCurrent = 1;
    if (lastStreakDate == yesterday) {
      newCurrent = currentStreak + 1;
    } else if (lastStreakDate == today) {
      newCurrent = currentStreak;
    } else {
      newCurrent = 1;
    }

    await _setInt(_kCurrentStreakKey, newCurrent);
    if (newCurrent > bestStreak) {
      await _setInt(_kBestStreakKey, newCurrent);
    }
    await _setString(_kLastStreakDateKey, today);
  }

  Future<void> forceReset() async {
    await _setInt(_kCurrentStreakKey, 0);
    await _setInt(_kTodayCountKey, 0);
    await _setString(_kTodayDateKey, '');
    await _setString(_kLastStreakDateKey, '');
  }

  Future<void> resetIfMissed() async {
    final lastStreakDate = _getString(_kLastStreakDateKey);
    if (lastStreakDate == null || lastStreakDate.isEmpty) return;
    final yesterday = _dateString(DateTime.now().subtract(Duration(days: 1)));
    final today = _dateString();
    if (lastStreakDate != yesterday && lastStreakDate != today) {
      await _setInt(_kCurrentStreakKey, 0);
    }
    final storedTodayDate = _getString(_kTodayDateKey);
    if (storedTodayDate != today) {
      await _setInt(_kTodayCountKey, 0);
      await _setString(_kTodayDateKey, '');
    }
  }
}

// Global singleton instance for easy access across the app
final StreakManager streakManager = StreakManager();
