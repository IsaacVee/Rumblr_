import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rumblr/core/models/fight_category.dart';
import 'package:rumblr/core/services/home_service.dart';
import 'package:rumblr/core/services/ranking_service.dart';

class FighterOption {
  FighterOption({
    required this.id,
    required this.displayName,
    this.primaryWeightClass,
    this.elo,
  });

  final String id;
  final String displayName;
  final String? primaryWeightClass;
  final double? elo;
}

class FightService {
  FightService({
    FirebaseFirestore? firestore,
    RankingService? rankingService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _rankingService = rankingService ?? RankingService();

  final FirebaseFirestore _firestore;
  final RankingService _rankingService;

  Future<List<FighterOption>> fetchOpponents(String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('fighters')
          .orderBy('username')
          .limit(50)
          .get();

      return snapshot.docs.where((doc) => doc.id != currentUserId).map((doc) {
        final data = doc.data();
        final username = (data['username'] as String?)?.trim();
        final primary = (data['primaryWeightClass'] as String?)?.trim();
        double? elo;
        final eloRatings = data['eloRatings'];
        if (eloRatings is Map<String, dynamic>) {
          final mmaElo = eloRatings['mma'];
          if (mmaElo is num) {
            elo = mmaElo.toDouble();
          }
        }
        return FighterOption(
          id: doc.id,
          displayName: username?.isNotEmpty == true ? username! : 'Fighter',
          primaryWeightClass: primary,
          elo: elo,
        );
      }).toList();
    } catch (e) {
      debugPrint('Failed to load opponents: $e');
      return <FighterOption>[];
    }
  }

  Future<void> logFight({
    required String currentUserId,
    required String opponentId,
    required String weightClass,
    required bool didWin,
    required FightCategory category,
    String? notes,
  }) async {
    final winnerId = didWin ? currentUserId : opponentId;
    final loserId = didWin ? opponentId : currentUserId;

    EloUpdateResult? result;
    String winnerName;
    String loserName;

    if (category.affectsElo) {
      result =
          await _rankingService.updateEloRating(winnerId, loserId, weightClass);
      winnerName = result.winnerName;
      loserName = result.loserName;
    } else {
      final winnerSnap =
          await _firestore.collection('fighters').doc(winnerId).get();
      final loserSnap =
          await _firestore.collection('fighters').doc(loserId).get();
      winnerName = _displayNameOf(winnerSnap.data()) ?? 'Winner';
      loserName = _displayNameOf(loserSnap.data()) ?? 'Opponent';
    }

    final payload = <String, Object?>{
      'winnerId': winnerId,
      'loserId': loserId,
      'weightClass': weightClass,
      'weightClassNormalised': weightClass.toLowerCase(),
      'notes': notes,
      'loggedBy': currentUserId,
      'participants': [winnerId, loserId],
      'winnerName': winnerName,
      'loserName': loserName,
      'category': category.id,
      'affectsElo': category.affectsElo,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (result != null) {
      payload.addAll({
        'winnerOldElo': result.winnerOldElo,
        'winnerNewElo': result.winnerNewElo,
        'loserOldElo': result.loserOldElo,
        'loserNewElo': result.loserNewElo,
        'winnerDelta': result.winnerDelta,
        'loserDelta': result.loserDelta,
      });
    }

    await _firestore.collection('fights').add(payload);
  }

  Future<FightHistoryResult> fetchFightHistory({
    required String userId,
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? weightClassFilter,
    FightResultFilter resultFilter = FightResultFilter.all,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('fights')
        .where('participants', arrayContains: userId);

    if (weightClassFilter != null && weightClassFilter.isNotEmpty) {
      query = query.where('weightClassNormalised',
          isEqualTo: weightClassFilter.toLowerCase());
    }

    query = query.orderBy('createdAt', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    var snapshot = await query.get();
    if (weightClassFilter != null &&
        weightClassFilter.isNotEmpty &&
        snapshot.docs.isEmpty) {
      // Fallback for older records that might not have the normalised field yet
      snapshot = await _firestore
          .collection('fights')
          .where('participants', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
    }

    final lowerWeightFilter = weightClassFilter?.toLowerCase();

    final fights = <FightSummary>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final createdAt =
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final winnerId = data['winnerId'] as String?;
      final winnerName = (data['winnerName'] as String?)?.trim() ?? 'Winner';
      final loserName = (data['loserName'] as String?)?.trim() ?? 'Opponent';
      final isWin = winnerId == userId;
      if (resultFilter == FightResultFilter.wins && !isWin) {
        continue;
      }
      if (resultFilter == FightResultFilter.losses && isWin) {
        continue;
      }
      final weightClass = (data['weightClass'] as String?)?.trim() ?? 'MMA';
      if (lowerWeightFilter != null &&
          lowerWeightFilter.isNotEmpty &&
          weightClass.toLowerCase() != lowerWeightFilter) {
        continue;
      }
      final opponentName = isWin ? loserName : winnerName;
      final category = FightCategoryX.fromId(data['category'] as String?);
      final eloDelta = category.affectsElo
          ? (isWin
                  ? (data['winnerDelta'] as num?)
                  : (data['loserDelta'] as num?))
              ?.toDouble()
          : null;
      fights.add(
        FightSummary(
          id: doc.id,
          opponentName: opponentName,
          weightClass: weightClass.toUpperCase(),
          createdAt: createdAt,
          isWin: isWin,
          category: category,
          eloDelta: eloDelta,
          notes: (data['notes'] as String?)?.trim(),
        ),
      );
    }

    return FightHistoryResult(
      fights: fights,
      lastDoc: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }
}

class FightHistoryResult {
  FightHistoryResult({
    required this.fights,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<FightSummary> fights;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

enum FightResultFilter { all, wins, losses }

String? _displayNameOf(Map<String, dynamic>? data) {
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
