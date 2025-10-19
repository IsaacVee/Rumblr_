import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rumblr/core/models/fighter_membership.dart';
import 'package:rumblr/core/models/membership_request.dart';

class MembershipService {
  MembershipService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _fighters =>
      _firestore.collection('fighters');

  CollectionReference<Map<String, dynamic>> _membershipRequests(String gymId) =>
      _firestore.collection('gyms').doc(gymId).collection('membershipRequests');

  Stream<List<MembershipRequest>> watchMembershipRequests(String gymId) {
    return _membershipRequests(gymId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(MembershipRequest.fromDoc)
              .toList(growable: false),
        );
  }

  Future<void> requestGymMembership({
    required String fighterId,
    required String gymId,
    String? message,
  }) async {
    final requestDoc = _membershipRequests(gymId).doc(fighterId);
    await requestDoc.set({
      'fighterId': fighterId,
      'gymId': gymId,
      'message': message,
      'status': FighterMembershipStatus.pending.id,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _fighters.doc(fighterId).update({
      'gymId': gymId,
      'membershipType': FighterMembershipType.gym.id,
      'membershipStatus': FighterMembershipStatus.pending.id,
      'membership': {
        'type': FighterMembershipType.gym.id,
        'status': FighterMembershipStatus.pending.id,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveGymMembership({
    required String fighterId,
    required String gymId,
    FighterRole role = FighterRole.fighter,
  }) async {
    await _membershipRequests(gymId).doc(fighterId).update({
      'status': FighterMembershipStatus.active.id,
      'updatedAt': FieldValue.serverTimestamp(),
      'approvedAt': FieldValue.serverTimestamp(),
    });

    await _fighters.doc(fighterId).update({
      'gymId': gymId,
      'membershipType': FighterMembershipType.gym.id,
      'membershipStatus': FighterMembershipStatus.active.id,
      'membership': {
        'type': FighterMembershipType.gym.id,
        'status': FighterMembershipStatus.active.id,
      },
      'role': role.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectGymMembership({
    required String fighterId,
    required String gymId,
    String? reason,
  }) async {
    await _membershipRequests(gymId).doc(fighterId).update({
      'status': FighterMembershipStatus.suspended.id,
      if (reason != null) 'reason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _fighters.doc(fighterId).update({
      'membershipType': FighterMembershipType.independent.id,
      'membershipStatus': FighterMembershipStatus.pending.id,
      'membership': {
        'type': FighterMembershipType.independent.id,
        'status': FighterMembershipStatus.pending.id,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBillingState({
    required String fighterId,
    required BillingState billingState,
  }) async {
    await _fighters.doc(fighterId).update({
      'billingState': billingState.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBlockedUsers({
    required String fighterId,
    required List<String> blockedUserIds,
  }) async {
    await _fighters.doc(fighterId).update({
      'blockedUserIds': blockedUserIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setIndependentMembership({
    required String fighterId,
    BillingState billingState = BillingState.trialing,
  }) async {
    try {
      await _fighters.doc(fighterId).update({
        'gymId': null,
        'membershipType': FighterMembershipType.independent.id,
        'membershipStatus': FighterMembershipStatus.active.id,
        'membership': {
          'type': FighterMembershipType.independent.id,
          'status': FighterMembershipStatus.active.id,
        },
        'billingState': billingState.id,
        'role': FighterRole.fighter.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Failed to set independent membership for $fighterId: $error');
    }
  }
}
