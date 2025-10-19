import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rumblr/core/models/fight_category.dart';
import 'package:rumblr/core/services/fight_service.dart';
import 'package:rumblr/core/services/ranking_service.dart';

class LogFightScreen extends StatefulWidget {
  const LogFightScreen({
    super.key,
    FightService? fightService,
    RankingService? rankingService,
  })  : _fightService = fightService,
        _rankingService = rankingService;

  final FightService? _fightService;
  final RankingService? _rankingService;

  @override
  State<LogFightScreen> createState() => _LogFightScreenState();
}

class _LogFightScreenState extends State<LogFightScreen> {
  late final FightService _fightService;
  late final RankingService _rankingService;
  late Future<_LogFightData> _loadFuture;

  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  String? _selectedOpponentId;
  String? _selectedWeightClass;
  FightCategory _selectedCategory = FightCategory.ranked;
  bool _didWin = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fightService = widget._fightService ?? FightService();
    _rankingService = widget._rankingService ?? RankingService();
    _loadFuture = _loadData();
    _loadFuture.then((data) {
      if (!mounted) return;
      setState(() {
        _selectedOpponentId =
            data.opponents.isNotEmpty ? data.opponents.first.id : null;
        _selectedWeightClass = data.weightClasses.isNotEmpty
            ? data.weightClasses.first
            : RankingService.defaultWeightClasses.first;
      });
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<_LogFightData> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to log a fight.');
    }
    final opponents = await _fightService.fetchOpponents(user.uid);
    final weightClasses = await _rankingService.getWeightClasses();
    return _LogFightData(opponents: opponents, weightClasses: weightClasses);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to log a fight.')),
      );
      return;
    }

    final opponentId = _selectedOpponentId;
    final weightClass =
        _selectedWeightClass ?? RankingService.defaultWeightClasses.first;

    if (opponentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an opponent to continue.')),
      );
      return;
    }

    try {
      setState(() => _isSubmitting = true);
      await _fightService.logFight(
        currentUserId: user.uid,
        opponentId: opponentId,
        weightClass: weightClass,
        didWin: _didWin,
        category: _selectedCategory,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;
      final successMessage = switch (_selectedCategory) {
        FightCategory.sparring =>
          'Sparring session logged. Rankings unchanged.',
        FightCategory.exhibition =>
          'Exhibition fight logged. Rankings unaffected.',
        FightCategory.ranked => 'Ranked fight logged! Rankings updated.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log fight: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Fight'),
      ),
      body: FutureBuilder<_LogFightData>(
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
                      'Unable to load fight logging data.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadFuture = _loadData();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;

          if (data.opponents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_search, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'No opponents found yet. Invite others to join or refresh later.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadFuture = _loadData();
                        });
                      },
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedOpponentId,
                    decoration: const InputDecoration(
                      labelText: 'Opponent',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null ? 'Select an opponent' : null,
                    items: data.opponents
                        .map(
                          (fighter) => DropdownMenuItem<String>(
                            value: fighter.id,
                            child: Text(
                              fighter.primaryWeightClass == null
                                  ? fighter.displayName
                                  : '${fighter.displayName} · ${fighter.primaryWeightClass!.toUpperCase()}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() => _selectedOpponentId = value);
                          },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<FightCategory>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Match Type',
                      border: OutlineInputBorder(),
                    ),
                    items: FightCategory.values
                        .map(
                          (category) => DropdownMenuItem<FightCategory>(
                            value: category,
                            child: Text(category.label),
                          ),
                        )
                        .toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _selectedCategory = value);
                          },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedCategory.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedWeightClass,
                    decoration: const InputDecoration(
                      labelText: 'Weight Class',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null ? 'Select a weight class' : null,
                    items: data.weightClasses
                        .map(
                          (weightClass) => DropdownMenuItem<String>(
                            value: weightClass,
                            child: Text(weightClass.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() => _selectedWeightClass = value);
                          },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<bool>(
                    value: _didWin,
                    decoration: const InputDecoration(
                      labelText: 'Result',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem<bool>(
                        value: true,
                        child: Text('I won'),
                      ),
                      DropdownMenuItem<bool>(
                        value: false,
                        child: Text('I lost'),
                      ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _didWin = value);
                          },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.publish),
                      label: Text(
                          _isSubmitting ? 'Logging Fight...' : 'Log Fight'),
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogFightData {
  _LogFightData({
    required this.opponents,
    required this.weightClasses,
  });

  final List<FighterOption> opponents;
  final List<String> weightClasses;
}
