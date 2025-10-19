import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:rumblr/core/models/fight_category.dart';
import 'package:rumblr/core/models/fighter.dart';

class FighterSummary {
  FighterSummary({
    required this.primaryWeightClass,
    required this.elo,
    required this.wins,
    required this.losses,
    this.streak = 0,
  });

  final String primaryWeightClass;
  final double elo;
  final int wins;
  final int losses;
  final int streak;

  String get record => '$wins-$losses';
}

class UpcomingEvent {
  UpcomingEvent({
    required this.id,
    required this.title,
    required this.date,
    this.location,
    this.description,
  });

  final String id;
  final String title;
  final DateTime date;
  final String? location;
  final String? description;
}

class DashboardHighlight {
  DashboardHighlight({
    required this.id,
    required this.title,
    required this.detail,
    this.author,
    this.createdAt,
    this.eloDelta,
    this.streak,
    this.weightClass,
  });

  final String id;
  final String title;
  final String detail;
  final String? author;
  final DateTime? createdAt;
  final double? eloDelta;
  final int? streak;
  final String? weightClass;

  String get initials {
    final source = author ?? title;
    final cleaned = source.trim();
    if (cleaned.isEmpty) {
      return 'R';
    }
    final parts = cleaned.split(RegExp(r'\s+')).take(2);
    return parts.map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
  }
}

class FightSummary {
  FightSummary({
    required this.id,
    required this.opponentName,
    required this.weightClass,
    required this.createdAt,
    required this.isWin,
    this.category = FightCategory.ranked,
    this.eloDelta,
    this.notes,
  });

  final String id;
  final String opponentName;
  final String weightClass;
  final DateTime createdAt;
  final bool isWin;
  final FightCategory category;
  final double? eloDelta;
  final String? notes;

  bool get affectsElo => category.affectsElo;
  String get categoryLabel => category.label;
  String get categoryDescription => category.description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'opponentName': opponentName,
        'weightClass': weightClass,
        'createdAt': createdAt.toIso8601String(),
        'isWin': isWin,
        'category': category.id,
        'eloDelta': eloDelta,
        'notes': notes,
      };

  factory FightSummary.fromJson(Map<String, dynamic> json) => FightSummary(
        id: json['id'] as String,
        opponentName: json['opponentName'] as String? ?? 'Opponent',
        weightClass: json['weightClass'] as String? ?? 'MMA',
        createdAt: DateTime.parse(json['createdAt'] as String),
        isWin: json['isWin'] as bool? ?? false,
        category: FightCategoryX.fromId(json['category'] as String?),
        eloDelta: (json['eloDelta'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
      );
}

class HomeDashboardData {
  HomeDashboardData({
    required this.summary,
    required this.events,
    required this.highlights,
    required this.recentFights,
  });

  final FighterSummary summary;
  final List<UpcomingEvent> events;
  final List<DashboardHighlight> highlights;
  final List<FightSummary> recentFights;
}

class HomeService {
  HomeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<Map<String, Object>> _defaultEvents = [
    {
      'title': 'Downtown Rumble',
      'location': 'BKLYN Fight Club',
      'description': 'Amateur MMA card with ELO points on the line.',
      'daysFromNow': 5,
    },
    {
      'title': 'Open Mat Meetup',
      'location': 'Queens MMA Collective',
      'description': 'Regional grappling open mat and sparring.',
      'daysFromNow': 9,
    },
  ];

  static const List<Map<String, String>> _defaultHighlights = [
    {
      'title': 'Welcome to Rumblr',
      'detail': 'Track fights, gyms, tournaments, and your climb to the top.',
      'author': 'Rumblr Team',
    },
    {
      'title': 'Climb The Ladder',
      'detail': 'Log fights consistently to boost your ELO ranking.',
    },
  ];

  Future<HomeDashboardData> fetchDashboard(String userId) async {
    final summaryFuture = _fetchFighterSummary(userId);
    final eventsFuture = _fetchUpcomingEvents();
    final highlightsFuture = _fetchHighlights();
    final fightsFuture = _fetchRecentFights(userId);

    final results = await Future.wait<dynamic>([
      summaryFuture,
      eventsFuture,
      highlightsFuture,
      fightsFuture,
    ]);

    return HomeDashboardData(
      summary: results[0] as FighterSummary,
      events: results[1] as List<UpcomingEvent>,
      highlights: results[2] as List<DashboardHighlight>,
      recentFights: results[3] as List<FightSummary>,
    );
  }

  Future<FighterSummary> _fetchFighterSummary(String userId) async {
    try {
      final doc = await _firestore.collection('fighters').doc(userId).get();
      if (!doc.exists) {
        return FighterSummary(
          primaryWeightClass: 'mma',
          elo: 1500,
          wins: 0,
          losses: 0,
        );
      }

      final fighter = Fighter.fromDoc(doc);
      String primaryClass = fighter.primaryWeightClass?.toLowerCase() ?? 'mma';
      double elo = 1500;
      if (fighter.eloRatings.isNotEmpty) {
        final sorted = fighter.eloRatings.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        primaryClass = sorted.first.key;
        elo = sorted.first.value;
      }
      final wins = fighter.records['wins'] ?? 0;
      final losses = fighter.records['losses'] ?? 0;
      final streak = fighter.streak;

      return FighterSummary(
        primaryWeightClass: primaryClass,
        elo: elo,
        wins: wins,
        losses: losses,
        streak: streak,
      );
    } catch (e) {
      debugPrint('Failed to load fighter summary: $e');
      return FighterSummary(
        primaryWeightClass: 'mma',
        elo: 1500,
        wins: 0,
        losses: 0,
      );
    }
  }

  Future<List<UpcomingEvent>> _fetchUpcomingEvents() async {
    final now = Timestamp.fromDate(DateTime.now());
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: now)
          .orderBy('date')
          .limit(5)
          .get();

      if (snapshot.docs.isEmpty) {
        await _seedDefaultEvents();
        final seededSnapshot = await _firestore
            .collection('events')
            .orderBy('date')
            .limit(5)
            .get();
        return seededSnapshot.docs.map(_mapEvent).toList();
      }

      return snapshot.docs.map(_mapEvent).toList();
    } on FirebaseException catch (e) {
      debugPrint('Primary events query failed: $e');
      try {
        final fallbackSnapshot = await _firestore
            .collection('events')
            .orderBy('date')
            .limit(5)
            .get();
        if (fallbackSnapshot.docs.isEmpty) {
          await _seedDefaultEvents();
          final seededSnapshot = await _firestore
              .collection('events')
              .orderBy('date')
              .limit(5)
              .get();
          return seededSnapshot.docs.map(_mapEvent).toList();
        }
        return fallbackSnapshot.docs.map(_mapEvent).toList();
      } catch (fallbackError) {
        debugPrint('Fallback events query failed: $fallbackError');
        return <UpcomingEvent>[];
      }
    } catch (e) {
      debugPrint('Failed to load events: $e');
      return <UpcomingEvent>[];
    }
  }

  UpcomingEvent _mapEvent(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final timestamp = data['date'] as Timestamp?;
    return UpcomingEvent(
      id: doc.id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'Upcoming Event',
      date: timestamp?.toDate() ?? DateTime.now(),
      location: (data['location'] as String?)?.trim(),
      description: (data['description'] as String?)?.trim(),
    );
  }

  Future<void> _seedDefaultEvents() async {
    final batch = _firestore.batch();
    final eventsCollection = _firestore.collection('events');
    final now = DateTime.now();

    for (var i = 0; i < _defaultEvents.length; i++) {
      final event = _defaultEvents[i];
      final docRef = eventsCollection.doc();
      final daysFromNow = event['daysFromNow'] as int? ?? (i + 3);

      batch.set(
          docRef,
          {
            'title': event['title'],
            'location': event['location'],
            'description': event['description'],
            'date': Timestamp.fromDate(now.add(Duration(days: daysFromNow))),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<List<DashboardHighlight>> _fetchHighlights() async {
    try {
      final snapshot = await _firestore
          .collection('highlights')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      if (snapshot.docs.isEmpty) {
        await _seedDefaultHighlights();
        final seededSnapshot = await _firestore
            .collection('highlights')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
        return seededSnapshot.docs.map(_mapHighlight).toList();
      }

      return snapshot.docs.map(_mapHighlight).toList();
    } on FirebaseException catch (e) {
      debugPrint('Failed to load highlights: $e');
      return <DashboardHighlight>[];
    }
  }

  DashboardHighlight _mapHighlight(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final metadata = data['metadata'] as Map<String, dynamic>?;
    final eloDelta = (metadata?['winnerDelta'] as num?)?.toDouble();
    final streak = (metadata?['winnerStreak'] as num?)?.toInt();
    final weightClass = (metadata?['weightClass'] as String?)?.trim();
    return DashboardHighlight(
      id: doc.id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'Highlight',
      detail: (data['detail'] as String?)?.trim() ??
          (data['subtitle'] as String?)?.trim() ??
          'Momentum update',
      author: (data['author'] as String?)?.trim(),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      eloDelta: eloDelta,
      streak: streak,
      weightClass: weightClass,
    );
  }

  Future<void> _seedDefaultHighlights() async {
    final batch = _firestore.batch();
    final highlightsCollection = _firestore.collection('highlights');

    for (final highlight in _defaultHighlights) {
      final docRef = highlightsCollection.doc();
      batch.set(
          docRef,
          {
            'title': highlight['title'],
            'detail': highlight['detail'],
            'author': highlight['author'],
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<List<FightSummary>> _fetchRecentFights(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('fights')
          .where('participants', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final winnerId = data['winnerId'] as String?;
        final winnerName = (data['winnerName'] as String?)?.trim() ?? 'Winner';
        final loserName = (data['loserName'] as String?)?.trim() ?? 'Opponent';
        final isWin = winnerId == userId;
        final category = FightCategoryX.fromId(data['category'] as String?);
        final opponentName = isWin ? loserName : winnerName;
        final eloDelta = category.affectsElo
            ? (isWin
                    ? (data['winnerDelta'] as num?)
                    : (data['loserDelta'] as num?))
                ?.toDouble()
            : null;
        return FightSummary(
          id: doc.id,
          opponentName: opponentName,
          weightClass: (data['weightClass'] as String?)?.toUpperCase() ?? 'MMA',
          createdAt: createdAt,
          isWin: isWin,
          category: category,
          eloDelta: eloDelta,
          notes: (data['notes'] as String?)?.trim(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Failed to load recent fights: $e');
      return <FightSummary>[];
    }
  }
}
