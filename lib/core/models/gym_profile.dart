import 'package:cloud_firestore/cloud_firestore.dart';

import 'fighter_membership.dart';

class GymProfile {
  GymProfile({
    required this.id,
    required this.name,
    required this.ownerUserId,
    this.slug,
    this.primaryEmblemUrl,
    this.emblemUrls = const [],
    this.region,
    this.subscriptionStatus = BillingState.trialing,
    this.stripeCustomerId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerUserId;
  final String? slug;
  final String? primaryEmblemUrl;
  final List<String> emblemUrls;
  final String? region;
  final BillingState subscriptionStatus;
  final String? stripeCustomerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory GymProfile.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final emblemData = data['emblems'];
    List<String> emblems = const [];
    if (emblemData is List) {
      emblems = emblemData.whereType<String>().toList(growable: false);
    }

    return GymProfile(
      id: snapshot.id,
      name: (data['name'] as String?)?.trim() ?? 'Gym',
      ownerUserId: (data['ownerUserId'] as String?) ?? '',
      slug: (data['slug'] as String?)?.trim(),
      primaryEmblemUrl: (data['primaryEmblemUrl'] as String?)?.trim(),
      emblemUrls: emblems,
      region: (data['region'] as String?)?.trim(),
      subscriptionStatus:
          BillingStateX.fromId(data['subscriptionStatus'] as String?),
      stripeCustomerId: (data['stripeCustomerId'] as String?)?.trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': name,
      'ownerUserId': ownerUserId,
      if (slug != null) 'slug': slug,
      if (primaryEmblemUrl != null) 'primaryEmblemUrl': primaryEmblemUrl,
      'emblems': emblemUrls,
      if (region != null) 'region': region,
      'subscriptionStatus': subscriptionStatus.id,
      if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
