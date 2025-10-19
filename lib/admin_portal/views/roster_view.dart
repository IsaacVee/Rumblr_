import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rumblr/core/models/fighter_membership.dart';
import 'package:rumblr/core/models/gym_roster_member.dart';
import 'package:rumblr/core/services/gym_portal_service.dart';

class RosterView extends StatelessWidget {
  RosterView({
    super.key,
    required this.selectedGymIdListenable,
  });

  final ValueListenable<String?> selectedGymIdListenable;
  final GymPortalService _gymPortalService = GymPortalService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedGymIdListenable,
      builder: (context, gymId, _) {
        if (gymId == null || gymId.isEmpty) {
          return _buildPlaceholder(
            context,
            'Select a gym to view its roster.',
          );
        }

        return StreamBuilder<List<GymRosterMember>>(
          stream: _gymPortalService.watchRoster(gymId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildPlaceholder(
                context,
                'Failed to load roster: ${snapshot.error}',
                isError: true,
              );
            }

            final members = snapshot.data ?? const [];
            if (members.isEmpty) {
              return _buildPlaceholder(
                context,
                'No fighters on the roster yet. Approve membership requests to populate this list.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(24.0),
              itemBuilder: (context, index) =>
                  _RosterListTile(member: members[index]),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: members.length,
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholder(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.people_outline,
              size: 48,
              color: isError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterListTile extends StatelessWidget {
  const _RosterListTile({required this.member});

  final GymRosterMember member;

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
      leading: const Icon(Icons.person),
      title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            firestore.collection('fighters').doc(member.fighterId).snapshots(),
        builder: (context, snapshot) {
          final fighterData = snapshot.data?.data();
          final name =
              (fighterData?['displayName'] as String?) ?? member.fighterId;
          final email = fighterData?['email'] as String?;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              if (email != null)
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Text(
                'User ID: ${member.fighterId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              avatar: const Icon(Icons.verified_user, size: 16),
              label: Text('Role: ${member.role.id}'),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text('Status: ${member.status.id}'),
              backgroundColor: _statusColor(member.status, context),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
      trailing: Text(
        member.addedAt != null ? 'Joined\n${member.addedAt}' : 'Pending record',
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  static Color? _statusColor(
      FighterMembershipStatus status, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case FighterMembershipStatus.pending:
        return scheme.surfaceVariant;
      case FighterMembershipStatus.active:
        return scheme.secondaryContainer;
      case FighterMembershipStatus.suspended:
        return scheme.errorContainer;
    }
  }
}
