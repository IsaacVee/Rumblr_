import 'package:flutter/material.dart';
import 'package:rumblr/core/models/fighter_membership.dart';
import 'package:rumblr/core/models/gym_profile.dart';
import 'package:rumblr/core/services/gym_portal_service.dart';

class SubscriptionStatusView extends StatelessWidget {
  SubscriptionStatusView({
    super.key,
    required this.selectedGymIdListenable,
  });

  final ValueListenable<String?> selectedGymIdListenable;
  final GymPortalService _gymPortalService = GymPortalService();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedGymIdListenable,
      builder: (context, gymId, _) {
        if (gymId == null || gymId.isEmpty) {
          return _buildPlaceholder(
            context,
            'Select a gym to view subscription status.',
          );
        }

        return StreamBuilder<GymProfile?>(
          stream: _gymPortalService.watchGym(gymId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildPlaceholder(
                context,
                'Failed to load gym: ${snapshot.error}',
                isError: true,
              );
            }

            final gym = snapshot.data;
            if (gym == null) {
              return _buildPlaceholder(
                context,
                'Gym not found. Double-check the ID.',
              );
            }

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: ListView(
                children: [
                  Text(
                    'Subscription',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gym.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text('Gym ID: ${gym.id}'),
                          if (gym.region != null) ...[
                            const SizedBox(height: 4),
                            Text('Region: ${gym.region}'),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('Current status:'),
                              const SizedBox(width: 12),
                              DropdownButton<BillingState>(
                                value: gym.subscriptionStatus,
                                onChanged: (newValue) async {
                                  if (newValue == null) return;
                                  try {
                                    await _gymPortalService.updateGymProfile(
                                      gymId: gym.id,
                                      subscriptionStatus: newValue,
                                    );
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to update status: $error',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                items: BillingState.values
                                    .map(
                                      (state) => DropdownMenuItem<BillingState>(
                                        value: state,
                                        child: Text(state.id),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Stripe Customer ID: ${gym.stripeCustomerId ?? 'Not linked'}',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Created: ${gym.createdAt?.toIso8601String() ?? 'Unknown'}',
                          ),
                          Text(
                            'Updated: ${gym.updatedAt?.toIso8601String() ?? 'Unknown'}',
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'To fully enable billing, integrate Stripe Checkout and webhooks to keep this status in sync.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
              isError ? Icons.error_outline : Icons.info_outline,
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
