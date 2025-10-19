import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RankingService {
  RankingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<String> defaultWeightClasses = <String>[
    'flyweight',
    'bantamweight',
    'featherweight',
    'lightweight',
    'welterweight',
    'middleweight',
    'light heavyweight',
    'heavyweight',
  ];

  Future<EloUpdateResult> updateEloRating(
    String winnerId,
    String loserId,
    String weightClass,
  ) async {
    final normalizedWeightClass = weightClass.trim().toLowerCase();

    final winnerRef = _firestore.collection('fighters').doc(winnerId);
    final loserRef = _firestore.collection('fighters').doc(loserId);

    final winnerSnap = await winnerRef.get();
    final loserSnap = await loserRef.get();

    if (!winnerSnap.exists || !loserSnap.exists) {
      throw StateError('Unable to update rankings: fighter profile missing.');
    }

    final winnerData = winnerSnap.data();
    final loserData = loserSnap.data();

    final winnerOldElo = _resolveElo(winnerData, normalizedWeightClass);
    final loserOldElo = _resolveElo(loserData, normalizedWeightClass);

    const double kFactor = 32;
    final expectedWinner =
        1 / (1 + math.pow(10, (loserOldElo - winnerOldElo) / 400));
    final expectedLoser = 1 - expectedWinner;

    final winnerNewElo = winnerOldElo + kFactor * (1 - expectedWinner);
    final loserNewElo = loserOldElo + kFactor * (0 - expectedLoser);

    final batch = _firestore.batch();
    batch.set(
      winnerRef,
      <String, Object?>{
        'eloRatings.$normalizedWeightClass': winnerNewElo,
        if (winnerData != null)
          'record': _updatedRecord(winnerData, didWin: true),
        'streak': _updatedStreak(winnerData, didWin: true),
        'lastFightAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      loserRef,
      <String, Object?>{
        'eloRatings.$normalizedWeightClass': loserNewElo,
        if (loserData != null)
          'record': _updatedRecord(loserData, didWin: false),
        'streak': _updatedStreak(loserData, didWin: false),
        'lastFightAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    return EloUpdateResult(
      winnerId: winnerId,
      loserId: loserId,
      weightClass: normalizedWeightClass,
      winnerName: _displayNameOf(winnerData) ?? 'Winner',
      loserName: _displayNameOf(loserData) ?? 'Opponent',
      winnerOldElo: winnerOldElo,
      winnerNewElo: winnerNewElo,
      loserOldElo: loserOldElo,
      loserNewElo: loserNewElo,
    );
  }

  Future<List<Map<String, dynamic>>> getRankings(String weightClass) async {
    final normalizedWeightClass = weightClass.trim().toLowerCase();
    final snapshot = await _firestore
        .collection('fighters')
        .orderBy('eloRatings.$normalizedWeightClass', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  Future<List<String>> getWeightClasses() async {
    try {
      final metadataDoc =
          await _firestore.collection('metadata').doc('weightClasses').get();
      final data = metadataDoc.data();
      final parsed =
          _parseWeightClasses(data?['options'] ?? data?['weightClasses']);
      if (parsed.isNotEmpty) {
        return parsed;
      }

      final collectionSnapshot =
          await _firestore.collection('weightClasses').get();
      final fromCollection = collectionSnapshot.docs
          .map((doc) => _parseWeightClasses(
              doc.data()['options'] ?? doc.data()['values']))
          .expand((list) => list)
          .toSet()
          .toList();
      if (fromCollection.isNotEmpty) {
        fromCollection.sort();
        return fromCollection;
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to load weight classes: $e\n$stackTrace');
    }
    return defaultWeightClasses;
  }

  static double _resolveElo(Map<String, dynamic>? data, String weightClass) {
    if (data == null) {
      return 1500;
    }
    final eloRatings = data['eloRatings'];
    if (eloRatings is Map<String, dynamic>) {
      final direct = eloRatings[weightClass];
      if (direct is num) {
        return direct.toDouble();
      }
      // Attempt to fall back to the first Elo entry if the specific class is missing.
      final firstEntry = eloRatings.entries.firstWhere(
        (entry) => entry.value is num,
        orElse: () => const MapEntry<String, dynamic>('mma', 1500),
      );
      final value = firstEntry.value;
      if (value is num) {
        return value.toDouble();
      }
    }
    return 1500;
  }

  static Map<String, Object?> _updatedRecord(Map<String, dynamic> data,
      {required bool didWin}) {
    final record = <String, int>{};
    final existingRecord = data['record'];
    if (existingRecord is Map<String, dynamic>) {
      for (final entry in existingRecord.entries) {
        final value = entry.value;
        if (value is num) {
          record[entry.key] = value.toInt();
        }
      }
    }

    final wins = record['wins'] ?? 0;
    final losses = record['losses'] ?? 0;

    if (didWin) {
      record['wins'] = wins + 1;
      record['losses'] = losses;
    } else {
      record['wins'] = wins;
      record['losses'] = losses + 1;
    }

    return record;
  }

  static int _updatedStreak(Map<String, dynamic>? data,
      {required bool didWin}) {
    final current = (data?['streak'] as num?)?.toInt() ?? 0;
    if (didWin) {
      return current >= 0 ? current + 1 : 1;
    }
    return current <= 0 ? current - 1 : -1;
  }

  static String? _displayNameOf(Map<String, dynamic>? data) {
    final username = (data?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }
    final gymName = (data?['gymName'] as String?)?.trim();
    if (gymName != null && gymName.isNotEmpty) {
      return gymName;
    }
    return null;
  }

  static List<String> _parseWeightClasses(Object? raw) {
    if (raw is List) {
      final cleaned = raw
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .map((value) => value.toLowerCase())
          .toSet()
          .toList(growable: false);
      cleaned.sort();
      return cleaned;
    }
    return const <String>[];
  }
}

class EloUpdateResult {
  EloUpdateResult({
    required this.winnerId,
    required this.loserId,
    required this.weightClass,
    required this.winnerName,
    required this.loserName,
    required this.winnerOldElo,
    required this.winnerNewElo,
    required this.loserOldElo,
    required this.loserNewElo,
  });

  final String winnerId;
  final String loserId;
  final String weightClass;
  final String winnerName;
  final String loserName;
  final double winnerOldElo;
  final double winnerNewElo;
  final double loserOldElo;
  final double loserNewElo;

  double get winnerDelta => winnerNewElo - winnerOldElo;
  double get loserDelta => loserNewElo - loserOldElo;
}
