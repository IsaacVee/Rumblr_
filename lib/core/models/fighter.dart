import 'package:cloud_firestore/cloud_firestore.dart';

import 'fighter_membership.dart';

class Fighter {
  Fighter({
    required this.id,
    required this.username,
    required this.email,
    required this.eloRatings,
    required this.records,
    required this.disciplines,
    this.primaryWeightClass,
    required this.createdAt,
    this.lastFightDate,
    this.streak = 0,
    this.gymId,
    this.membershipType = FighterMembershipType.independent,
    this.membershipStatus = FighterMembershipStatus.pending,
    this.billingState = BillingState.trialing,
    this.role = FighterRole.fighter,
    this.blockedUserIds = const <String>[],
  });

  final String id;
  final String username;
  final String email;
  final Map<String, double> eloRatings;
  final Map<String, int> records;
  final List<String> disciplines;
  final String? primaryWeightClass;
  final DateTime createdAt;
  final DateTime? lastFightDate;
  final int streak;
  final String? gymId;
  final FighterMembershipType membershipType;
  final FighterMembershipStatus membershipStatus;
  final BillingState billingState;
  final FighterRole role;
  final List<String> blockedUserIds;

  factory Fighter.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final eloRaw = data['eloRatings'];
    final recordRaw = data['record'];
    final disciplineRaw = data['disciplines'];

    final eloMap = <String, double>{};
    if (eloRaw is Map) {
      for (final entry in eloRaw.entries) {
        final key = entry.key?.toString();
        final value = entry.value;
        if (key != null && value is num) {
          eloMap[key] = value.toDouble();
        }
      }
    }

    final recordsMap = <String, int>{};
    if (recordRaw is Map) {
      for (final entry in recordRaw.entries) {
        final key = entry.key?.toString();
        final value = entry.value;
        if (key != null && value is num) {
          recordsMap[key] = value.toInt();
        }
      }
    }

    final disciplinesList = <String>[];
    if (disciplineRaw is List) {
      for (final value in disciplineRaw) {
        if (value is String && value.trim().isNotEmpty) {
          disciplinesList.add(value.trim());
        }
      }
    }

    final createdAtTs = data['createdAt'] as Timestamp?;
    final lastFightTs = data['lastFightAt'] as Timestamp?;

    final streak = (data['streak'] as num?)?.toInt() ?? 0;
    final membershipMap = data['membership'];
    final membershipTypeId = (data['membershipType'] as String?) ??
        (membershipMap is Map ? membershipMap['type'] as String? : null);
    final membershipStatusId = (data['membershipStatus'] as String?) ??
        (membershipMap is Map ? membershipMap['status'] as String? : null);
    final billingStateId = data['billingState'] as String?;
    final roleId = data['role'] as String?;
    final blockedRaw = data['blockedUserIds'];
    List<String> blocked = const [];
    if (blockedRaw is List) {
      blocked = blockedRaw.whereType<String>().toList(growable: false);
    }

    return Fighter(
      id: doc.id,
      username: (data['username'] as String?)?.trim() ?? 'Fighter',
      email: (data['email'] as String?)?.trim() ?? '',
      eloRatings: eloMap,
      records: recordsMap,
      disciplines: disciplinesList,
      primaryWeightClass: (data['primaryWeightClass'] as String?)?.trim(),
      createdAt:
          createdAtTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      lastFightDate: lastFightTs?.toDate(),
      streak: streak,
      gymId: (data['gymId'] as String?)?.trim(),
      membershipType: FighterMembershipTypeX.fromId(membershipTypeId),
      membershipStatus: FighterMembershipStatusX.fromId(membershipStatusId),
      billingState: BillingStateX.fromId(billingStateId),
      role: FighterRoleX.fromId(roleId),
      blockedUserIds: blocked,
    );
  }
}
