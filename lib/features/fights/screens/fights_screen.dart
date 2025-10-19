import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rumblr/core/services/fight_service.dart';
import 'package:rumblr/core/services/home_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FightsScreen extends StatefulWidget {
  const FightsScreen({super.key, FightService? fightService})
      : _fightService = fightService;

  final FightService? _fightService;

  @override
  State<FightsScreen> createState() => _FightsScreenState();
}

class _FightsScreenState extends State<FightsScreen> {
  static const _pageSize = 20;
  static const _allWeightClasses = 'All';
  static const _cachePrefix = 'fight_cache_v1';

  late final FightService _fightService;
  final Map<_FilterKey, _FightCache> _cache = {};
  final Set<String> _weightClassSet = {_allWeightClasses};

  String? _userId;
  String _selectedWeightClass = _allWeightClasses;
  FightResultFilter _resultFilter = FightResultFilter.all;

  _FilterKey get _currentKey => _FilterKey(
        weightClass: _selectedWeightClass,
        resultFilter: _resultFilter,
      );

  _FightCache get _currentCache =>
      _cache.putIfAbsent(_currentKey, _FightCache.new);

  @override
  void initState() {
    super.initState();
    _fightService = widget._fightService ?? FightService();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _activateCache();
    _loadCacheForCurrentFilter();
  }

  void _activateCache() {
    final cache = _currentCache;
    _weightClassSet
      ..clear()
      ..add(_allWeightClasses)
      ..addAll(cache.fights.map((f) => f.weightClass));
  }

  Future<void> _loadMore() async {
    final cache = _currentCache;
    if (cache.isLoading || !cache.hasMore || _userId == null) return;

    setState(() => cache.isLoading = true);

    final hadPrefData = cache.loadedFromPrefs && cache.lastDoc == null;

    final result = await _fightService.fetchFightHistory(
      userId: _userId!,
      limit: _pageSize,
      startAfter: cache.lastDoc,
      weightClassFilter: _selectedWeightClass == _allWeightClasses
          ? null
          : _selectedWeightClass,
      resultFilter: _resultFilter,
    );

    setState(() {
      Set<String> existingIds;
      if (hadPrefData) {
        cache.fights.clear();
        cache.loadedFromPrefs = false;
        existingIds = <String>{};
        _weightClassSet
          ..clear()
          ..add(_allWeightClasses);
      } else {
        existingIds = cache.fights.map((f) => f.id).toSet();
      }

      for (final fight in result.fights) {
        if (existingIds.add(fight.id)) {
          cache.fights.add(fight);
          _weightClassSet.add(fight.weightClass);
        }
      }

      cache.lastDoc = result.lastDoc;
      cache.hasMore = result.hasMore;
      cache.isLoading = false;
    });

    unawaited(_saveCacheForCurrentFilter());
  }

  Future<void> _refresh() async {
    final cache = _currentCache;
    setState(() {
      cache.fights.clear();
      cache.lastDoc = null;
      cache.hasMore = true;
      cache.loadedFromPrefs = false;
      _weightClassSet
        ..clear()
        ..add(_allWeightClasses);
    });
    unawaited(_clearCacheForCurrentFilter());
    await _loadMore();
  }

  void _onWeightClassChanged(String? value) {
    if (value == null) return;
    setState(() => _selectedWeightClass = value);
    _activateCache();
    _loadCacheForCurrentFilter();
  }

  void _onResultFilterChanged(FightResultFilter filter) {
    if (_resultFilter == filter) return;
    setState(() => _resultFilter = filter);
    _activateCache();
    _loadCacheForCurrentFilter();
  }

  Future<void> _loadCacheForCurrentFilter() async {
    if (_userId == null) return;
    final key = _currentKey;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || key != _currentKey) return;

    final cacheKey = _prefsKeyForFilter(key);
    final cached = prefs.getString(cacheKey);

    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final fightsJson = (decoded['fights'] as List?) ?? const [];
        final fights = fightsJson
            .whereType<Map<String, dynamic>>()
            .map(FightSummary.fromJson)
            .toList();
        setState(() {
          final cache = _currentCache;
          cache.fights
            ..clear()
            ..addAll(fights);
          cache.lastDoc = null;
          cache.hasMore = true;
          cache.loadedFromPrefs = fights.isNotEmpty;
          _weightClassSet
            ..clear()
            ..add(_allWeightClasses)
            ..addAll(cache.fights.map((f) => f.weightClass));
        });
      } catch (e) {
        debugPrint('Failed to decode fight cache: $e');
      }
    }

    if (mounted && key == _currentKey) {
      _loadMore();
    }
  }

  Future<void> _saveCacheForCurrentFilter() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final cache = _currentCache;
    final payload = {
      'fights': cache.fights.take(50).map((f) => f.toJson()).toList(),
    };
    await prefs.setString(_prefsKeyForFilter(_currentKey), jsonEncode(payload));
  }

  Future<void> _clearCacheForCurrentFilter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyForFilter(_currentKey));
  }

  String _prefsKeyForFilter(_FilterKey key) =>
      '${_cachePrefix}_${key.weightClass}_${key.resultFilter.name}';

  @override
  Widget build(BuildContext context) {
    final weightClasses = _weightClassSet.toList()..sort();
    final fights = _currentCache.fights;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fight History'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: fights.length + (_currentCache.hasMore ? 1 : 0) + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedWeightClass,
                    decoration: const InputDecoration(
                      labelText: 'Weight Class',
                      border: OutlineInputBorder(),
                    ),
                    items: weightClasses
                        .map(
                          (weightClass) => DropdownMenuItem<String>(
                            value: weightClass,
                            child: Text(weightClass),
                          ),
                        )
                        .toList(),
                    onChanged:
                        _currentCache.isLoading ? null : _onWeightClassChanged,
                  ),
                  const SizedBox(height: 12),
                  ToggleButtons(
                    isSelected: FightResultFilter.values
                        .map((filter) => filter == _resultFilter)
                        .toList(),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: (index) =>
                        _onResultFilterChanged(FightResultFilter.values[index]),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('All'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Wins'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Losses'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }

            final fightIndex = index - 1;
            if (fightIndex >= fights.length) {
              _loadMore();
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return _FightHistoryTile(summary: fights[fightIndex]);
          },
        ),
      ),
    );
  }
}

class _FightHistoryTile extends StatelessWidget {
  const _FightHistoryTile({required this.summary});

  final FightSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('MMM d • h:mm a').format(summary.createdAt);
    final resultLabel = summary.isWin ? 'Win' : 'Loss';
    final resultColor = summary.isWin ? Colors.green : Colors.red;
    final eloDelta = summary.eloDelta;
    final categoryLabel = summary.categoryLabel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
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
              Text(summary.notes!, style: theme.textTheme.bodySmall),
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
      ),
    );
  }
}

class _FilterKey {
  const _FilterKey({required this.weightClass, required this.resultFilter});

  final String weightClass;
  final FightResultFilter resultFilter;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _FilterKey &&
        other.weightClass == weightClass &&
        other.resultFilter == resultFilter;
  }

  @override
  int get hashCode => Object.hash(weightClass, resultFilter);
}

class _FightCache {
  final List<FightSummary> fights = [];
  DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  bool hasMore = true;
  bool isLoading = false;
  bool loadedFromPrefs = false;
}
