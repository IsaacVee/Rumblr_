import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rumblr/core/models/fighter_membership.dart';
import 'package:rumblr/core/models/gym_profile.dart';
import 'package:rumblr/core/models/gym_roster_member.dart';

class GymPortalService {
  GymPortalService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _gymsCollection =>
      _firestore.collection('gyms');

  CollectionReference<Map<String, dynamic>> _gymRoster(String gymId) =>
      _gymsCollection.doc(gymId).collection('roster');

  Stream<GymProfile?> watchGym(String gymId) {
    return _gymsCollection.doc(gymId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return GymProfile.fromDoc(snapshot);
    });
  }

  Stream<List<GymRosterMember>> watchRoster(String gymId) {
    return _gymRoster(gymId).snapshots().map(
          (snapshot) => snapshot.docs
              .map(GymRosterMember.fromDoc)
              .toList(growable: false),
        );
  }

  Future<GymProfile> createGym({
    required String ownerUserId,
    required String name,
    String? slug,
    String? region,
    String? primaryEmblemUrl,
    List<String> emblemUrls = const [],
  }) async {
    final gymDoc = _gymsCollection.doc();
    final payload = {
      'name': name.trim(),
      'ownerUserId': ownerUserId,
      if (slug != null) 'slug': slug.trim(),
      if (region != null) 'region': region.trim(),
      if (primaryEmblemUrl != null) 'primaryEmblemUrl': primaryEmblemUrl.trim(),
      'emblems': emblemUrls,
      'subscriptionStatus': BillingState.trialing.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await gymDoc.set(payload);
    return GymProfile.fromDoc(await gymDoc.get());
  }

  Future<void> updateGymProfile({
    required String gymId,
    String? name,
    String? region,
    String? primaryEmblemUrl,
    List<String>? emblemUrls,
    BillingState? subscriptionStatus,
    String? stripeCustomerId,
  }) async {
    final update = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) update['name'] = name.trim();
    if (region != null) update['region'] = region.trim();
    if (primaryEmblemUrl != null) {
      update['primaryEmblemUrl'] = primaryEmblemUrl.trim();
    }
    if (emblemUrls != null) update['emblems'] = emblemUrls;
    if (subscriptionStatus != null) {
      update['subscriptionStatus'] = subscriptionStatus.id;
    }
    if (stripeCustomerId != null) {
      update['stripeCustomerId'] = stripeCustomerId;
    }

    await _gymsCollection.doc(gymId).update(update);
  }

  Future<void> addFighterToRoster({
    required String gymId,
    required String fighterId,
    required FighterMembershipStatus status,
    FighterRole role = FighterRole.fighter,
  }) async {
    final rosterDoc = _gymRoster(gymId).doc(fighterId);
    await rosterDoc.set({
      'status': status.id,
      'role': role.id,
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeFighterFromRoster({
    required String gymId,
    required String fighterId,
  }) async {
    try {
      await _gymRoster(gymId).doc(fighterId).delete();
    } catch (error) {
      debugPrint('Failed to remove fighter $fighterId from gym $gymId: $error');
    }
  }
}
