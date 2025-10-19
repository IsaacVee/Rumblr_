import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rumblr/core/constants/app_routes.dart';
import 'package:rumblr/core/services/auth_service.dart';
import 'package:rumblr/core/services/home_service.dart';
import 'package:rumblr/core/services/notification_service.dart';
import 'package:rumblr/features/home/widgets/action_chip_button.dart';
import 'package:rumblr/features/home/widgets/dashboard_section.dart';
import 'package:rumblr/features/home/widgets/quick_stat_tile.dart';
import 'package:rumblr/features/home/widgets/upcoming_event_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, HomeService? homeService})
      : _homeService = homeService;

  final HomeService? _homeService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeService _homeService;
  Future<HomeDashboardData>? _dashboardFuture;
  bool _tokenRegistered = false;

  @override
  void initState() {
    super.initState();
    _homeService = widget._homeService ?? HomeService();
    _dashboardFuture = _fetchDashboard();
  }

  Future<HomeDashboardData> _fetchDashboard() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    if (!_tokenRegistered) {
      _tokenRegistered = true;
      unawaited(NotificationService.registerDeviceToken(user.uid));
    }
    return _homeService.fetchDashboard(user.uid);
  }

  Future<void> _refresh() async {
    final future = _fetchDashboard();
    setState(() => _dashboardFuture = future);
    await future;
  }

  Future<void> _scheduleDebugReminder() async {
    try {
      final startDate = DateTime.now().add(const Duration(minutes: 2));
      await NotificationService.scheduleTournamentReminder(
        tournamentId: 'debug-demo',
        title: 'Debug Rumble',
        startDate: startDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debug reminder scheduled for ~1 minute from now.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to schedule debug reminder: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rumblr Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<HomeDashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                children: [
                  Text(
                    'We couldn\'t load your dashboard right now.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'Welcome back, fighter! 👊',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                DashboardSection(
                  title: 'Quick Actions',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ActionChipButton(
                        icon: Icons.bar_chart,
                        label: 'Rankings',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.rankings),
                      ),
                      ActionChipButton(
                        icon: Icons.sports_mma,
                        label: 'Log Fight',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.logFight),
                      ),
                      ActionChipButton(
                        icon: Icons.search,
                        label: 'Find Gym',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.gymSearch),
                      ),
                      ActionChipButton(
                        icon: Icons.emoji_events,
                        label: 'Tournaments',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.tournaments),
                      ),
                      if (kDebugMode)
                        ActionChipButton(
                          icon: Icons.notifications_active,
                          label: 'Test Reminder',
                          onPressed: _scheduleDebugReminder,
                        ),
                    ],
                  ),
                ),
                DashboardSection(
                  title: 'Your Stats',
                  trailing: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Detailed stats coming soon.')),
                      );
                    },
                    child: const Text('View all'),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: QuickStatTile(
                          icon: Icons.military_tech,
                          value: data.summary.elo.toStringAsFixed(0),
                          label:
                              'ELO - ${data.summary.primaryWeightClass.toUpperCase()}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: QuickStatTile(
                          icon: Icons.sports_kabaddi,
                          value: data.summary.record,
                          label: 'Fight Record',
                        ),
                      ),
                      if (data.summary.streak != 0) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: QuickStatTile(
                            icon: Icons.trending_up,
                            value: _formatStreak(data.summary.streak),
                            label: 'Current Streak',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                DashboardSection(
                  title: 'Recent Fights',
                  trailing: TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.fights),
                    child: const Text('View all'),
                  ),
                  child: data.recentFights.isEmpty
                      ? _buildEmptyState(
                          context, 'No fights logged yet. Step into the cage!')
                      : Column(
                          children: [
                            for (var i = 0;
                                i < data.recentFights.length;
                                i++) ...[
                              _RecentFightTile(summary: data.recentFights[i]),
                              if (i < data.recentFights.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                ),
                DashboardSection(
                  title: 'Upcoming Events',
                  trailing: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Events schedule coming soon.')),
                      );
                    },
                    child: const Text('See all'),
                  ),
                  child: data.events.isEmpty
                      ? _buildEmptyState(
                          context, 'No upcoming events yet. Check back soon!')
                      : Column(
                          children: [
                            for (var i = 0; i < data.events.length; i++) ...[
                              UpcomingEventTile(
                                title: data.events[i].title,
                                date: _formatEventDate(
                                    context, data.events[i].date),
                                location: data.events[i].location,
                              ),
                              if (i < data.events.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                ),
                DashboardSection(
                  title: 'Latest Highlights',
                  child: data.highlights.isEmpty
                      ? _buildEmptyState(context,
                          'No highlights yet. Win a fight to get featured!')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0;
                                i < data.highlights.length;
                                i++) ...[
                              _HighlightTile(highlight: data.highlights[i]),
                              if (i < data.highlights.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }

  String _formatEventDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = DateFormat('EEE · MMM d', locale);
    return formatter.format(date);
  }

  static String _formatStreak(int streak) {
    if (streak == 0) return 'Even';
    if (streak > 0) {
      return 'W$streak';
    }
    return 'L${streak.abs()}';
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.highlight});

  final DashboardHighlight highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(highlight.initials),
            ),
            title: Text(highlight.title),
            subtitle: Text(_buildSubtitle(context, highlight)),
          ),
          if (highlight.eloDelta != null ||
              highlight.streak != null ||
              highlight.weightClass != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (highlight.weightClass != null &&
                    highlight.weightClass!.isNotEmpty)
                  Chip(
                    label: Text(highlight.weightClass!.toUpperCase()),
                    visualDensity: VisualDensity.compact,
                  ),
                if (highlight.eloDelta != null && highlight.eloDelta!.abs() > 0)
                  Chip(
                    avatar: Icon(
                      highlight.eloDelta! >= 0
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 16,
                      color:
                          highlight.eloDelta! >= 0 ? Colors.green : Colors.red,
                    ),
                    label: Text(
                      '${highlight.eloDelta! >= 0 ? '+' : ''}${highlight.eloDelta!.toStringAsFixed(0)} ELO',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (highlight.streak != null && highlight.streak != 0)
                  Chip(
                    avatar: const Icon(Icons.local_fire_department,
                        size: 16, color: Colors.orange),
                    label: Text(_formatStreak(highlight.streak!)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _buildSubtitle(BuildContext context, DashboardHighlight highlight) {
    final createdAt = highlight.createdAt;
    final author = highlight.author;

    String dateLabel = '';
    if (createdAt != null) {
      final locale = Localizations.localeOf(context).toString();
      final formatter = DateFormat('MMM d', locale);
      dateLabel = ' · ${formatter.format(createdAt)}';
    }

    if (author != null && author.isNotEmpty) {
      return '${highlight.detail} · $author$dateLabel';
    }

    return '${highlight.detail}$dateLabel';
  }

  static String _formatStreak(int streak) {
    if (streak == 0) return 'Even';
    if (streak > 0) {
      return 'W$streak';
    }
    return 'L${streak.abs()}';
  }
}

class _RecentFightTile extends StatelessWidget {
  const _RecentFightTile({required this.summary});

  final FightSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('MMM d • h:mm a').format(summary.createdAt);
    final resultLabel = summary.isWin ? 'Win' : 'Loss';
    final resultColor = summary.isWin ? Colors.green : Colors.red;
    final eloDelta = summary.eloDelta;
    final categoryLabel = summary.categoryLabel;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: resultColor.withValues(alpha: 0.15),
        foregroundColor: resultColor,
        child: Text(summary.isWin ? 'W' : 'L'),
      ),
      title: Text('vs ${summary.opponentName}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '$categoryLabel • $resultLabel · ${summary.weightClass} · $dateLabel'),
          if (!summary.affectsElo)
            Text(
              'Rankings unchanged for this match type.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          if (summary.notes != null && summary.notes!.isNotEmpty)
            Text(
              summary.notes!,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
      trailing: eloDelta == null
          ? null
          : Chip(
              label: Text(
                '${eloDelta >= 0 ? '+' : ''}${eloDelta.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: eloDelta >= 0 ? Colors.green : Colors.red,
            ),
    );
  }
}
