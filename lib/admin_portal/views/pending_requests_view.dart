import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rumblr/core/models/fighter_membership.dart';
import 'package:rumblr/core/models/membership_request.dart';
import 'package:rumblr/core/services/gym_portal_service.dart';
import 'package:rumblr/core/services/membership_service.dart';

class PendingRequestsView extends StatelessWidget {
  PendingRequestsView({
    super.key,
    required this.selectedGymIdListenable,
    this.onMembershipAction,
  });

  final ValueListenable<String?> selectedGymIdListenable;
  final VoidCallback? onMembershipAction;

  final MembershipService _membershipService = MembershipService();
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
            'Select a gym to review membership requests.',
          );
        }

        return StreamBuilder<List<MembershipRequest>>(
          stream: _membershipService.watchMembershipRequests(gymId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildPlaceholder(
                context,
                'Failed to load requests: ${snapshot.error}',
                isError: true,
              );
            }

            final requests = snapshot.data
                    ?.where((request) =>
                        request.status == FighterMembershipStatus.pending)
                    .toList(growable: false) ??
                const [];

            if (requests.isEmpty) {
              return _buildPlaceholder(
                context,
                'No pending membership requests at the moment.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(24.0),
              itemBuilder: (context, index) => _RequestCard(
                  request: requests[index],
                  gymId: gymId,
                  onMembershipAction: onMembershipAction,
                  membershipService: _membershipService,
                  gymPortalService: _gymPortalService,
                  firestore: _firestore),
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemCount: requests.length,
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
              isError ? Icons.error_outline : Icons.inbox_outlined,
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

class _RequestCard extends StatefulWidget {
  const _RequestCard({
    required this.request,
    required this.gymId,
    required this.onMembershipAction,
    required this.membershipService,
    required this.gymPortalService,
    required this.firestore,
  });

  final MembershipRequest request;
  final String gymId;
  final VoidCallback? onMembershipAction;
  final MembershipService membershipService;
  final GymPortalService gymPortalService;
  final FirebaseFirestore firestore;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _isProcessing = false;

  Future<void> _approve(FighterRole role) async {
    setState(() => _isProcessing = true);
    try {
      await widget.membershipService.approveGymMembership(
        fighterId: widget.request.fighterId,
        gymId: widget.gymId,
        role: role,
      );
      await widget.gymPortalService.addFighterToRoster(
        gymId: widget.gymId,
        fighterId: widget.request.fighterId,
        status: FighterMembershipStatus.active,
        role: role,
      );
      widget.onMembershipAction?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Approved ${widget.request.fighterId} as ${role.id}.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _isProcessing = true);
    try {
      await widget.membershipService.rejectGymMembership(
        fighterId: widget.request.fighterId,
        gymId: widget.gymId,
      );
      await widget.gymPortalService.removeFighterFromRoster(
        gymId: widget.gymId,
        fighterId: widget.request.fighterId,
      );
      widget.onMembershipAction?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected ${widget.request.fighterId}.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: widget.firestore
                  .collection('fighters')
                  .doc(widget.request.fighterId)
                  .snapshots(),
              builder: (context, snapshot) {
                final fighterData = snapshot.data?.data();
                final displayName = (fighterData?['displayName'] as String?) ??
                    widget.request.fighterId;
                final email = fighterData?['email'] as String?;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (email != null)
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      'User ID: ${widget.request.fighterId}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (widget.request.message != null)
              Text(
                '"${widget.request.message}"',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            Text(
              'Submitted: ${widget.request.submittedAt ?? 'Unknown'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _approve(FighterRole.fighter),
                  icon: const Icon(Icons.check),
                  label:
                      Text(_isProcessing ? 'Processing' : 'Approve as Fighter'),
                ),
                OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _approve(FighterRole.gymAdmin),
                  icon: const Icon(Icons.security),
                  label: const Text('Approve as Gym Admin'),
                ),
                TextButton.icon(
                  onPressed: _isProcessing ? null : _reject,
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
