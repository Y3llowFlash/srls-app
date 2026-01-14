import 'package:cloud_firestore/cloud_firestore.dart';

enum ReviewRating { hard, medium, easy }

class SrsResult {
  final int reps;
  final int intervalDays;
  final double easeFactor;
  final Timestamp dueAt;

  SrsResult({
    required this.reps,
    required this.intervalDays,
    required this.easeFactor,
    required this.dueAt,
  });
}

class SrsMath {
  static const double _minEase = 1.3;
  static const double _maxEase = 3.0;

  static double _clampEase(double v) {
    if (v < _minEase) return _minEase;
    if (v > _maxEase) return _maxEase;
    return v;
  }

  /// ⭐ modifier: starred items should come a bit sooner
  /// (so interval is slightly smaller)
  static double _starModifier(bool isStarred) => isStarred ? 0.9 : 1.0;

  /// Compute next schedule from current state + rating
  static SrsResult next({
    required int reps,
    required int intervalDays,
    required double easeFactor,
    required bool isStarred,
    required ReviewRating rating,
    DateTime? now,
  }) {
    final baseNow = now ?? DateTime.now();

    // --- ease adjustment ---
    final easeDelta = switch (rating) {
      ReviewRating.hard => -0.20,
      ReviewRating.medium => -0.05,
      ReviewRating.easy => 0.05,
    };

    final newEase = _clampEase(easeFactor + easeDelta);

    // --- interval calculation ---
    int newInterval;

    if (reps == 0) {
      newInterval = switch (rating) {
        ReviewRating.hard => 1,
        ReviewRating.medium => 1,
        ReviewRating.easy => 2,
      };
    } else if (reps == 1) {
      newInterval = switch (rating) {
        ReviewRating.hard => 1,
        ReviewRating.medium => 3,
        ReviewRating.easy => 4,
      };
    } else {
      final multiplier = switch (rating) {
        ReviewRating.hard => 0.8,
        ReviewRating.medium => 1.0,
        ReviewRating.easy => 1.3,
      };

      final raw = intervalDays * newEase * multiplier * _starModifier(isStarred);
      newInterval = raw.round();

      if (newInterval < 1) newInterval = 1;
    }

    // --- reps update ---
    // MVP rule: hard does NOT reset reps; it just shortens interval and reduces ease
    final newReps = reps + 1;

    // --- dueAt ---
    final due = baseNow.add(Duration(days: newInterval));

    return SrsResult(
      reps: newReps,
      intervalDays: newInterval,
      easeFactor: newEase,
      dueAt: Timestamp.fromDate(due),
    );
  }
}
