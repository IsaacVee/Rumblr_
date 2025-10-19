import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rumblr/core/models/fighter_membership.dart';

class GymRosterMember {
  GymRosterMember({
    required this.fighterId,
    this.status = FighterMembershipStatus.pending,
    this.role = FighterRole.fighter,
    this.addedAt,
  });

  final String fighterId;
  final FighterMembershipStatus status;
  final FighterRole role;
  final DateTime? addedAt;

  factory GymRosterMember.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return GymRosterMember(
      fighterId: snapshot.id,
      status: FighterMembershipStatusX.fromId(data['status'] as String?),
      role: FighterRoleX.fromId(data['role'] as String?),
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
    );
  }
}
