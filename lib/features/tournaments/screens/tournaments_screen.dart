import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rumblr/core/constants/app_routes.dart';
import 'package:rumblr/core/services/tournament_service.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key, TournamentService? tournamentService})
      : _tournamentService = tournamentService;

  final TournamentService? _tournamentService;

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  late final TournamentService _tournamentService;
  Future<List<Tournament>>? _loadFuture;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tournamentService = widget._tournamentService ?? TournamentService();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadFuture = _tournamentService.fetchTournaments(userId: _userId);
  }

  Future<void> _refresh() async {
    setState(() {
      _loadFuture = _tournamentService.fetchTournaments(userId: _userId);
    });
    await _loadFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
      ),
      body: FutureBuilder<List<Tournament>>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load tournaments.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final tournaments = snapshot.data ?? [];
          if (tournaments.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No tournaments announced yet. Check back soon.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: tournaments.length,
              itemBuilder: (context, index) {
                final tournament = tournaments[index];
                return _TournamentCard(
                  tournament: tournament,
                  onTap: () async {
                    final updated = await Navigator.pushNamed(
                      context,
                      AppRoutes.tournamentDetail,
                      arguments: tournament,
                    );
                    if (updated == true) {
                      _refresh();
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament, this.onTap});

  final Tournament tournament;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d');
    final endDateFormat = DateFormat('MMM d');
    final startLabel = dateFormat.format(tournament.startDate);
    final endLabel = tournament.endDate != null ? endDateFormat.format(tournament.endDate!) : null;
    final durationLabel = endLabel == null ? startLabel : '$startLabel - $endLabel';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tournament.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(durationLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tournament.city,
                style: theme.textTheme.bodyMedium,
              ),
              if (tournament.description != null && tournament.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  tournament.description!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (tournament.entryFee != null)
                    Chip(
                      avatar: const Icon(Icons.attach_money, size: 18),
                      label: Text('Entry: \$${tournament.entryFee!.toStringAsFixed(0)}'),
                    ),
                  if (tournament.prizePool != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Chip(
                        avatar: const Icon(Icons.emoji_events, size: 18),
                        label: Text(tournament.prizePool!),
                      ),
                    ),
                  if (tournament.isRegistered)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Chip(
                        avatar: Icon(Icons.check_circle, color: Colors.green, size: 18),
                        label: Text('Registered'),
                      ),
                    ),
                ],
              ),
              if (tournament.divisions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Divisions',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
            ],
          ),
        ),
      ),
    );
  }
}
