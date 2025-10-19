import 'package:cloud_firestore/cloud_firestore.dart';

import 'fighter_membership.dart';

class MembershipRequest {
  MembershipRequest({
    required this.fighterId,
    required this.gymId,
    this.message,
    this.status = FighterMembershipStatus.pending,
    this.submittedAt,
    this.updatedAt,
    this.approvedAt,
    this.reason,
  });

  final String fighterId;
  final String gymId;
  final String? message;
  final FighterMembershipStatus status;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final String? reason;

  factory MembershipRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return MembershipRequest(
      fighterId: snapshot.id,
      gymId: (data['gymId'] as String?) ?? '',
      message: (data['message'] as String?)?.trim(),
      status: FighterMembershipStatusX.fromId(data['status'] as String?),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      reason: (data['reason'] as String?)?.trim(),
    );
  }
}
