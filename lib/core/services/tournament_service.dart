import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Tournament {
  Tournament({
    required this.id,
    required this.name,
    required this.city,
    required this.startDate,
    this.endDate,
    this.description,
    this.entryFee,
    this.divisions = const [],
    this.prizePool,
    this.contactEmail,
    this.contactPhone,
    this.registrationLink,
    this.isRegistered = false,
  });

  final String id;
  final String name;
  final String city;
  final DateTime startDate;
  final DateTime? endDate;
  final String? description;
  final double? entryFee;
  final List<String> divisions;
  final String? prizePool;
  final String? contactEmail;
  final String? contactPhone;
  final String? registrationLink;
  final bool isRegistered;
}

class TournamentService {
  TournamentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static final List<Map<String, Object>> _defaultTournaments = [
    {
      'name': 'NYC Open Mat Classic',
      'city': 'New York, NY',
      'description': 'Gi + No-Gi brackets with live ELO updates.',
      'daysFromNow': 12,
      'durationDays': 1,
      'entryFee': 65.0,
      'prizePool': 'Medals + Sponsor gear',
      'divisions': ['Beginner', 'Intermediate', 'Advanced'],
      'contactEmail': 'nyc-openmat@example.com',
      'registrationLink': 'https://nyc-openmat.example.com/register',
    },
    {
      'name': 'Brooklyn Fight Night',
      'city': 'Brooklyn, NY',
      'description': 'Amateur MMA showcase with cash prizes.',
      'daysFromNow': 21,
      'durationDays': 2,
      'entryFee': 125.0,
      'prizePool': 'Top 3 finishers share \$5k purse',
      'divisions': ['Featherweight', 'Lightweight', 'Welterweight'],
      'contactPhone': '+1 718-555-7788',
      'registrationLink': 'https://bklyn-fight-night.example.com/apply',
    },
  ];

  Future<List<Tournament>> fetchTournaments({required String? userId}) async {
    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .orderBy('startDate')
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) {
        await _seedTournaments();
        final seededSnapshot = await _firestore
            .collection('tournaments')
            .orderBy('startDate')
            .limit(20)
            .get();
        return seededSnapshot.docs
            .map((doc) => _mapTournament(doc, userId))
            .toList();
      }

      return snapshot.docs.map((doc) => _mapTournament(doc, userId)).toList();
    } catch (e) {
      debugPrint('Failed to load tournaments: $e');
      return <Tournament>[];
    }
  }

  Future<Tournament?> fetchTournament(String id,
      {required String? userId}) async {
    try {
      final doc = await _firestore.collection('tournaments').doc(id).get();
      if (!doc.exists) {
        return null;
      }
      return _mapTournamentFromDoc(doc, userId);
    } catch (e) {
      debugPrint('Failed to load tournament $id: $e');
      return null;
    }
  }

  Tournament _mapTournament(
      QueryDocumentSnapshot<Map<String, dynamic>> doc, String? userId) {
    return _mapTournamentFromDoc(doc, userId);
  }

  Tournament _mapTournamentFromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, String? userId) {
    final data = doc.data() ?? {};
    final startTimestamp = data['startDate'] as Timestamp?;
    final endTimestamp = data['endDate'] as Timestamp?;
    final entryFee = (data['entryFee'] as num?)?.toDouble();
    final divisionsRaw = data['divisions'];
    final divisions = divisionsRaw is List
        ? divisionsRaw
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final registeredUsers = data['registeredUsers'];
    bool isRegistered = false;
    if (registeredUsers is List && userId != null) {
      isRegistered = registeredUsers.cast<String>().contains(userId);
    }

    return Tournament(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? 'Tournament',
      city: (data['city'] as String?)?.trim() ?? 'Unknown city',
      description: (data['description'] as String?)?.trim(),
      startDate: startTimestamp?.toDate() ?? DateTime.now(),
      endDate: endTimestamp?.toDate(),
      entryFee: entryFee,
      divisions: divisions,
      prizePool: (data['prizePool'] as String?)?.trim(),
      contactEmail: (data['contactEmail'] as String?)?.trim(),
      contactPhone: (data['contactPhone'] as String?)?.trim(),
      registrationLink: (data['registrationLink'] as String?)?.trim(),
      isRegistered: isRegistered,
    );
  }

  Future<void> toggleRegistration(
      {required String tournamentId,
      required String userId,
      required bool register}) async {
    final docRef = _firestore.collection('tournaments').doc(tournamentId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Tournament not found');
      }
      final registeredUsers =
          snapshot.data()?['registeredUsers'] as List<dynamic>? ?? <dynamic>[];
      final users = registeredUsers.whereType<String>().toSet();
      if (register) {
        users.add(userId);
      } else {
        users.remove(userId);
      }
      transaction.update(docRef, {
        'registeredUsers': users.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _seedTournaments() async {
    final batch = _firestore.batch();
    final collection = _firestore.collection('tournaments');
    final now = DateTime.now();

    for (final tournament in _defaultTournaments) {
      final docRef = collection.doc();
      final daysFromNow = tournament['daysFromNow'] as int? ?? 7;
      final durationDays = tournament['durationDays'] as int? ?? 1;
      final startDate = now.add(Duration(days: daysFromNow));
      final endDate = startDate.add(Duration(days: durationDays));

      batch.set(
          docRef,
          {
            'name': tournament['name'],
            'city': tournament['city'],
            'description': tournament['description'],
            'startDate': Timestamp.fromDate(startDate),
            'endDate': Timestamp.fromDate(endDate),
            'entryFee': tournament['entryFee'],
            'prizePool': tournament['prizePool'],
            'divisions': tournament['divisions'],
            'contactEmail': tournament['contactEmail'],
            'contactPhone': tournament['contactPhone'],
            'registrationLink': tournament['registrationLink'],
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }

    await batch.commit();
  }
}
