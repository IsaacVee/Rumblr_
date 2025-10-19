import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rumblr/core/services/tournament_service.dart';
import 'package:rumblr/core/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TournamentDetailScreen extends StatelessWidget {
  const TournamentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final tournament = args is Tournament ? args : null;

    if (tournament == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: const Center(child: Text('Tournament not found.')),
      );
    }

    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMM d · h:mm a');
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(tournament.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            tournament.city,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            dateFormat.format(tournament.startDate),
            style: theme.textTheme.bodyMedium,
          ),
          if (tournament.endDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Ends: ${dateFormat.format(tournament.endDate!)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (tournament.description != null && tournament.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              tournament.description!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          if (tournament.entryFee != null) ...[
            _DetailRow(
              icon: Icons.attach_money,
              label: 'Entry Fee',
              value: '\$${tournament.entryFee!.toStringAsFixed(0)}',
            ),
          ],
          if (tournament.prizePool != null && tournament.prizePool!.isNotEmpty) ...[
            _DetailRow(
              icon: Icons.emoji_events,
              label: 'Prize Pool',
              value: tournament.prizePool!,
            ),
          ],
          if (tournament.contactEmail != null && tournament.contactEmail!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _LinkTile(
              icon: Icons.email,
              label: 'Contact Email',
              value: tournament.contactEmail!,
              onTap: (ctx) => _launchUrl(ctx, 'mailto:${tournament.contactEmail}'),
            ),
          ],
          if (tournament.contactPhone != null && tournament.contactPhone!.isNotEmpty) ...[
            _LinkTile(
              icon: Icons.phone,
              label: 'Contact Phone',
              value: tournament.contactPhone!,
              onTap: (ctx) => _launchUrl(ctx, 'tel:${_sanitizePhone(tournament.contactPhone!)}'),
            ),
          ],
          if (tournament.registrationLink != null && tournament.registrationLink!.isNotEmpty) ...[
            _LinkTile(
              icon: Icons.launch,
              label: 'Registration',
              value: tournament.registrationLink!,
              onTap: (ctx) => _launchUrl(ctx, tournament.registrationLink!),
              isLink: true,
            ),
          ],
          if (tournament.divisions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Divisions',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tournament.divisions
                  .map(
                    (division) => Chip(
                      label: Text(division),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          if (userId != null)
            _buildRsvpButton(context, tournament, userId)
          else
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sign in to register.')),
                );
              },
              icon: const Icon(Icons.lock),
              label: const Text('Sign in to register'),
            ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url.startsWith('http') || url.startsWith('mailto') || url.startsWith('tel')
        ? url
        : 'https://$url');
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to open link.')),
      );
    }
  }

  String _sanitizePhone(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

  Widget _buildRsvpButton(BuildContext context, Tournament tournament, String userId) {
    final theme = Theme.of(context);
    if (tournament.isRegistered) {
      return FilledButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cancel registration?'),
              content: Text('Remove your RSVP for ${tournament.name}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Cancel RSVP'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await TournamentService().toggleRegistration(
              tournamentId: tournament.id,
              userId: userId,
              register: false,
            );
            await NotificationService.cancelTournamentReminder(tournament.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed RSVP for ${tournament.name}.')),
              );
              Navigator.pop(context, true);
            }
          }
        },
        icon: const Icon(Icons.check_circle),
        label: const Text('Registered'),
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          foregroundColor: theme.colorScheme.onSurface,
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () async {
        try {
          await TournamentService().toggleRegistration(
            tournamentId: tournament.id,
            userId: userId,
            register: true,
          );
          await NotificationService.scheduleTournamentReminder(
            tournamentId: tournament.id,
            title: tournament.name,
            startDate: tournament.startDate,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Registered for ${tournament.name}!')),
            );
            Navigator.pop(context, true);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to RSVP: $e')),
            );
          }
        }
      },
      icon: const Icon(Icons.how_to_reg),
      label: const Text('Register Now'),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isLink = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final ValueChanged<BuildContext> onTap;
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isLink ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => onTap(context),
    );
  }
}
