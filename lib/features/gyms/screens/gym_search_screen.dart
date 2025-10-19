import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rumblr/core/services/gym_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class GymSearchScreen extends StatefulWidget {
  const GymSearchScreen({super.key, GymService? gymService}) : _gymService = gymService;

  final GymService? _gymService;

  @override
  State<GymSearchScreen> createState() => _GymSearchScreenState();
}

class _GymSearchScreenState extends State<GymSearchScreen> {
  static const _debounceDuration = Duration(milliseconds: 350);
  static const _prefsLatKey = 'gym_search_latitude';
  static const _prefsLngKey = 'gym_search_longitude';
  static const _prefsRadiusKey = 'gym_search_radius_km';
  static const _prefsLabelKey = 'gym_search_location_label';

  late final GymService _gymService;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  Future<_GymSearchData>? _loadFuture;
  List<Gym> _allGyms = const [];
  List<Gym> _gyms = const [];
  String? _selectedDiscipline;
  List<String> _disciplines = const [];
  bool _isLoading = false;
  LatLng? _userLocation;
  double? _radiusKm;
  String? _locationLabel;

  static const List<_PresetLocation> _presetLocations = [
    _PresetLocation('Downtown Brooklyn', LatLng(40.6955, -73.9870)),
    _PresetLocation('Long Island City', LatLng(40.7440, -73.9485)),
    _PresetLocation('Harlem', LatLng(40.8116, -73.9465)),
    _PresetLocation('Clear Location', null),
  ];

  @override
  void initState() {
    super.initState();
    _gymService = widget._gymService ?? GymService();
    _loadFuture = _initialize();
    _searchController.addListener(_onSearchChanged);
  }

  Future<_GymSearchData> _initialize() async {
    await _restoreLocationPrefs();
    final data = await _loadGyms();
    if (mounted) {
      setState(() {
        _allGyms = data.gyms;
        _disciplines = data.disciplines;
        _gyms = _filterGyms(data.gyms);
      });
    }
    return data;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _refreshGyms);
  }

  Future<_GymSearchData> _loadGyms({String? query, String? discipline}) async {
    final gyms = await _gymService.fetchGyms(
      query: query,
      discipline: discipline,
      userLocation: _userLocation,
    );
    final disciplineSet = <String>{'all'};
    for (final gym in gyms) {
      disciplineSet.addAll(gym.disciplines);
    }
    final disciplines = disciplineSet.toList()..sort();
    return _GymSearchData(gyms: gyms, disciplines: disciplines);
  }

  Future<void> _refreshGyms() async {
    setState(() => _isLoading = true);
    final query = _searchController.text.trim();
    final data = await _loadGyms(query: query, discipline: _selectedDiscipline);
    if (!mounted) return;
    setState(() {
      _allGyms = data.gyms;
      _disciplines = data.disciplines;
      _applyFilters();
    });
  }

  void _onDisciplineSelected(String discipline) {
    setState(() {
      _selectedDiscipline = discipline == 'all' ? null : discipline;
    });
    _refreshGyms();
  }

  void _selectLocation(_PresetLocation preset) {
    setState(() {
      _userLocation = preset.coords;
      _locationLabel = preset.label == 'Clear Location' ? null : preset.label;
      if (_userLocation == null) {
        _radiusKm = null;
      } else {
        _radiusKm ??= 15;
      }
    });
    _saveLocationPrefs();
    _refreshGyms();
  }

  void _applyFilters() {
    _gyms = _filterGyms(_allGyms);
    _isLoading = false;
  }

  List<Gym> _filterGyms(List<Gym> gyms) {
    if (_userLocation != null && _radiusKm != null) {
      final radius = _radiusKm! + 0.01;
      return gyms.where((gym) => gym.distanceKm == null || gym.distanceKm! <= radius).toList();
    }
    return gyms;
  }

  Future<void> _restoreLocationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_prefsLatKey);
    final lng = prefs.getDouble(_prefsLngKey);
    final radius = prefs.getDouble(_prefsRadiusKey);
    final label = prefs.getString(_prefsLabelKey);

    if (lat != null && lng != null) {
      _userLocation = LatLng(lat, lng);
    }
    if (radius != null) {
      _radiusKm = radius;
    }
    if (label != null && label.isNotEmpty) {
      _locationLabel = label;
    }
  }

  Future<void> _saveLocationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userLocation != null) {
      await prefs.setDouble(_prefsLatKey, _userLocation!.latitude);
      await prefs.setDouble(_prefsLngKey, _userLocation!.longitude);
      if (_radiusKm != null) {
        await prefs.setDouble(_prefsRadiusKey, _radiusKm!);
      }
      await prefs.setString(_prefsLabelKey, _locationLabel ?? 'Saved Location');
    } else {
      await prefs.remove(_prefsLatKey);
      await prefs.remove(_prefsLngKey);
      await prefs.remove(_prefsRadiusKey);
      await prefs.remove(_prefsLabelKey);
    }
  }

  Future<void> _useCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied.')),
      );
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable location services to use this feature.')),
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _locationLabel = 'My Location';
        _radiusKm ??= 15;
      });
      await _saveLocationPrefs();
      await _refreshGyms();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get current location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Gym'),
      ),
      body: FutureBuilder<_GymSearchData>(
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
                      'Could not load gyms right now.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadFuture = _initialize();
                        });
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _refreshGyms();
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search gyms, cities, or disciplines',
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _refreshGyms();
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preset locations',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    TextButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use current'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetLocations.map((preset) {
                    final bool selected = preset.coords == null
                        ? _userLocation == null && preset.label == 'Clear Location'
                        : _userLocation == preset.coords;
                    return ChoiceChip(
                      label: Text(preset.label),
                      selected: selected,
                      onSelected: (_) => _selectLocation(preset),
                    );
                  }).toList(),
                ),
                if (_userLocation != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _locationLabel ?? 'Custom location',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text('${(_radiusKm ?? 15).toStringAsFixed(0)} km radius'),
                    ],
                  ),
                  Slider(
                    value: _radiusKm ?? 15,
                    min: 3,
                    max: 50,
                    divisions: 47,
                    label: '${(_radiusKm ?? 15).toStringAsFixed(0)} km',
                    onChanged: (value) {
                      setState(() => _radiusKm = value);
                      _applyFilters();
                    },
                    onChangeEnd: (_) => _saveLocationPrefs(),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _disciplines
                      .map(
                        (discipline) => ChoiceChip(
                          label: Text(discipline.toUpperCase()),
                          selected: (_selectedDiscipline ?? 'all') == discipline,
                          onSelected: (selected) {
                            if (selected) {
                              _onDisciplineSelected(discipline);
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                if (_isLoading) ...[
                  const Center(child: CircularProgressIndicator()),
                ] else if (_gyms.isEmpty) ...[
                  const SizedBox(height: 24),
                  const Center(child: Text('No gyms matched your search. Try adjusting filters.')),
                ] else ...[
                  for (final gym in _gyms) _GymCard(gym: gym),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GymSearchData {
  _GymSearchData({required this.gyms, required this.disciplines});

  final List<Gym> gyms;
  final List<String> disciplines;
}

class _GymCard extends StatelessWidget {
  const _GymCard({required this.gym});

  final Gym gym;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    gym.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (gym.rating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(gym.rating!.toStringAsFixed(1)),
                    ],
                  ),
                if (gym.distanceKm != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: Text('${gym.distanceKm!.toStringAsFixed(1)} km'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(gym.city, style: theme.textTheme.bodyMedium),
            if (gym.address != null) ...[
              const SizedBox(height: 4),
              Text(
                gym.address!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            if (gym.disciplines.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: gym.disciplines
                    .map(
                      (discipline) => Chip(
                        label: Text(discipline.toUpperCase()),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (gym.dropInFee != null) ...[
              const SizedBox(height: 12),
              Text('Drop-in: \$${gym.dropInFee!.toStringAsFixed(0)}', style: theme.textTheme.bodyMedium),
            ],
            if (gym.membershipOptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Memberships', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...gym.membershipOptions.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $option', style: theme.textTheme.bodySmall),
                ),
              ),
            ],
            if (gym.phone != null || gym.website != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (gym.phone != null)
                    OutlinedButton.icon(
                      onPressed: () => _launchPhone(context, gym.phone!),
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
                    ),
                  if (gym.website != null)
                    OutlinedButton.icon(
                      onPressed: () => _launchWebsite(context, gym.website!),
                      icon: const Icon(Icons.launch),
                      label: const Text('Website'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhone(BuildContext context, String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    final sanitized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: sanitized);
    if (!await launchUrl(uri)) {
      _showLaunchError(messenger);
    }
  }

  Future<void> _launchWebsite(BuildContext context, String website) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(website.startsWith('http') ? website : 'https://$website');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showLaunchError(messenger);
    }
  }

  void _showLaunchError(ScaffoldMessengerState messenger) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Unable to open link')),
    );
  }
}

class _PresetLocation {
  const _PresetLocation(this.label, this.coords);

  final String label;
  final LatLng? coords;
}
