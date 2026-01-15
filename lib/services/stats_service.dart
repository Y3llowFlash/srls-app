import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatsService {
  final FirebaseFirestore _db;

  StatsService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw Exception('Not logged in');
    return u.uid;
  }

  DocumentReference<Map<String, dynamic>> _dailyDoc(String yyyyMmDd) => _db
      .collection('users')
      .doc(_uid)
      .collection('stats')
      .doc('daily_$yyyyMmDd');

  DocumentReference<Map<String, dynamic>> _summaryDoc() => _db
      .collection('users')
      .doc(_uid)
      .collection('stats')
      .doc('summary');

  String todayKeyUtcSafe() {
    // Using local date is fine for MVP; later you can align to user timezone.
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String yesterdayKeyUtcSafe() {
    final now = DateTime.now().subtract(const Duration(days: 1));
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Call after each successful rating.
  /// Call after each successful rating.
  Future<void> recordReview({int defaultGoal = 20}) async {
    final today = todayKeyUtcSafe();
    final yesterday = yesterdayKeyUtcSafe();

    final dailyRef = _dailyDoc(today);
    final summaryRef = _summaryDoc();

    await _db.runTransaction((tx) async {
      // ✅ READS FIRST
      final dailySnap = await tx.get(dailyRef);
      final sumSnap = await tx.get(summaryRef);

      // ---- daily ----
      final currentDone =
          (dailySnap.data()?['reviewsDone'] as num?)?.toInt() ?? 0;
      final currentGoal =
          (dailySnap.data()?['goal'] as num?)?.toInt() ?? defaultGoal;

      // ---- summary ----
      final lastActive = (sumSnap.data()?['lastActiveDate'] as String?) ?? '';
      final streak = (sumSnap.data()?['streakDays'] as num?)?.toInt() ?? 0;
      final total = (sumSnap.data()?['totalReviews'] as num?)?.toInt() ?? 0;

      int newStreak;
      if (lastActive == today) {
        newStreak = streak;
      } else if (lastActive == yesterday) {
        newStreak = streak <= 0 ? 1 : streak + 1;
      } else {
        newStreak = 1;
      }

      // ✅ WRITES AFTER ALL READS
      tx.set(dailyRef, {
        'date': today,
        'reviewsDone': currentDone + 1,
        'goal': currentGoal,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(summaryRef, {
        'lastActiveDate': today,
        'streakDays': newStreak,
        'totalReviews': total + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }


  Stream<Map<String, dynamic>> watchToday({int defaultGoal = 20}) {
    final today = todayKeyUtcSafe();
    return _dailyDoc(today).snapshots().map((snap) {
      final data = snap.data() ?? {};
      data['goal'] = (data['goal'] as num?)?.toInt() ?? defaultGoal;
      data['reviewsDone'] = (data['reviewsDone'] as num?)?.toInt() ?? 0;
      data['date'] = data['date'] ?? today;
      return data;
    });
  }

  Stream<Map<String, dynamic>> watchSummary() {
    return _summaryDoc().snapshots().map((snap) => snap.data() ?? {});
  }
}
