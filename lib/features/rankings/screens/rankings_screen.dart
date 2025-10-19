import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rumblr/core/services/ranking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef RankingsLoader = Future<List<Map<String, dynamic>>> Function(String weightClass);
typedef WeightClassesLoader = Future<List<String>> Function();
typedef WeightClassValueLoader = Future<String?> Function();
typedef WeightClassValueSaver = Future<void> Function(String weightClass);

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({
    super.key,
    this.initialWeightClass = 'mma',
    RankingsLoader? loadRankings,
    WeightClassesLoader? loadWeightClasses,
    WeightClassValueLoader? loadLastWeightClass,
    WeightClassValueSaver? saveLastWeightClass,
    this.weightClasses = RankingService.defaultWeightClasses,
  })  : _loadRankings = loadRankings ?? _defaultRankingsLoader,
        _loadWeightClasses = loadWeightClasses ?? _defaultWeightClassesLoader,
        _loadLastWeightClass = loadLastWeightClass ?? _defaultLastWeightClassLoader,
        _saveLastWeightClass = saveLastWeightClass ?? _defaultLastWeightClassSaver;

  final String initialWeightClass;
  final RankingsLoader _loadRankings;
  final WeightClassesLoader _loadWeightClasses;
  final WeightClassValueLoader _loadLastWeightClass;
  final WeightClassValueSaver _saveLastWeightClass;
  final List<String> weightClasses;

  static const String _weightClassPrefsKey = 'rankings_last_weight_class';

  static Future<List<Map<String, dynamic>>> _defaultRankingsLoader(String weightClass) {
    return RankingService().getRankings(weightClass);
  }

  static Future<List<String>> _defaultWeightClassesLoader() {
    return RankingService().getWeightClasses();
  }

  static Future<String?> _defaultLastWeightClassLoader() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_weightClassPrefsKey);
  }

  static Future<void> _defaultLastWeightClassSaver(String weightClass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weightClassPrefsKey, weightClass);
  }

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  Future<List<Map<String, dynamic>>>? _rankingsFuture;
  late String _weightClass;
  late List<String> _weightClasses;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _weightClasses = widget.weightClasses;
    _weightClass = _resolveInitialWeightClass(widget.initialWeightClass, _weightClasses);
    _initialize();
  }

  String _resolveInitialWeightClass(String desired, List<String> available) {
    if (available.isEmpty) {
      return desired;
    }
    if (available.contains(desired)) {
      return desired;
    }
    return available.first;
  }

  Future<void> _initialize() async {
    try {
      final fetchedClasses = await widget._loadWeightClasses();
      final available = fetchedClasses.isNotEmpty ? fetchedClasses : widget.weightClasses;
      final saved = await widget._loadLastWeightClass();
      var nextClass = saved ?? widget.initialWeightClass;
      nextClass = _resolveInitialWeightClass(nextClass, available);
      final future = widget._loadRankings(nextClass);
      unawaited(widget._saveLastWeightClass(nextClass));
      if (!mounted) return;
      setState(() {
        _weightClasses = available;
        _weightClass = nextClass;
        _rankingsFuture = future;
        _initializing = false;
      });
    } catch (_) {
      final future = widget._loadRankings(_weightClass);
      if (!mounted) return;
      setState(() {
        _rankingsFuture = future;
        _initializing = false;
      });
    }
  }

  Future<void> _refresh() async {
    final future = widget._loadRankings(_weightClass);
    setState(() {
      _rankingsFuture = future;
    });
    await future;
  }

  void _onWeightClassChanged(String? newValue) {
    if (newValue == null || newValue == _weightClass) {
      return;
    }
    unawaited(widget._saveLastWeightClass(newValue));
    final future = widget._loadRankings(newValue);
    setState(() {
      _weightClass = newValue;
      _rankingsFuture = future;
    });
  }

  Widget _buildWeightClassSelector() {
    if (_weightClasses.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentValue = _weightClasses.contains(_weightClass) ? _weightClass : _weightClasses.first;

    return Row(
      children: [
        const Text('Weight Class'),
        const SizedBox(width: 12),
        DropdownButton<String>(
          key: const Key('weight-class-dropdown'),
          value: currentValue,
          onChanged: _onWeightClassChanged,
          items: _weightClasses
              .map(
                (weightClass) => DropdownMenuItem<String>(
                  value: weightClass,
                  child: Text(weightClass),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rankings'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _rankingsFuture,
          builder: (context, snapshot) {
            final rankings = snapshot.data ?? [];
            final connection = snapshot.connectionState;
            final isWaiting =
                _initializing || connection == ConnectionState.waiting || connection == ConnectionState.none;

            Widget? statusWidget;
            if (isWaiting) {
              statusWidget = const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              statusWidget = Center(
                child: Text(
                  'Failed to load rankings. Please try again.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            } else if (rankings.isEmpty) {
              statusWidget = const Center(
                child: Text('No fighters ranked yet. Check back soon!'),
              );
            }

            final children = <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildWeightClassSelector(),
              ),
              const SizedBox(height: 16),
            ];

            if (statusWidget != null) {
              children.add(Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: statusWidget,
              ));
            } else {
              for (var i = 0; i < rankings.length; i++) {
                final fighter = rankings[i];
                final displayName = fighter['username'] as String? ?? 'Unknown Fighter';
                final eloRatings = fighter['eloRatings'] as Map<String, dynamic>?;
                final eloValue = (eloRatings?[_weightClass] ?? fighter['elo'] ?? 1500).toString();

                children.add(ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(displayName),
                  subtitle: Text('ELO: $eloValue'),
                ));

                if (i < rankings.length - 1) {
                  children.add(const Divider(height: 1));
                }
              }
            }

            if (children.length == 2) {
              children.add(const SizedBox(height: 200));
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              children: children,
            );
          },
        ),
      ),
    );
  }
}
