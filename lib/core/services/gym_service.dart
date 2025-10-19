import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class GymService {
  GymService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<Map<String, Object>> _defaultGyms = [
    {
      'name': 'El Niño Training Center',
      'city': 'San Francisco, CA',
      'address': '2929 3rd St, San Francisco, CA 94107',
      'phone': '+1 415-552-4522',
      'website': 'https://elninotrainingcenter.com',
      'disciplines': ['mma', 'muay thai', 'bjj'],
      'dropInFee': 35,
      'rating': 4.8,
      'latitude': 37.75532,
      'longitude': -122.38825,
      'membershipOptions': [
        'Unlimited training - \$199/mo',
        'Striking program - \$149/mo',
      ],
    },
    {
      'name': 'American Kickboxing Academy',
      'city': 'San Jose, CA',
      'address': '7012 Realm Dr, San Jose, CA 95119',
      'phone': '+1 408-225-9000',
      'website': 'https://akakickbox.com',
      'disciplines': ['mma', 'wrestling', 'muay thai', 'bjj'],
      'dropInFee': 40,
      'rating': 4.8,
      'latitude': 37.23378,
      'longitude': -121.79064,
      'membershipOptions': [
        'Pro team access - \$250/mo',
        'All levels membership - \$199/mo',
      ],
    },
    {
      'name': 'Ralph Gracie Jiu-Jitsu San Francisco',
      'city': 'San Francisco, CA',
      'address': '110 Sutter St, San Francisco, CA 94104',
      'phone': '+1 415-433-6500',
      'website': 'https://ralphgracie.com',
      'disciplines': ['bjj', 'jiu jitsu'],
      'dropInFee': 30,
      'rating': 4.9,
      'latitude': 37.79058,
      'longitude': -122.40053,
      'membershipOptions': [
        'Unlimited BJJ - \$225/mo',
        'Fundamentals plan - \$165/mo',
      ],
    },
    {
      'name': 'San Francisco Judo Institute',
      'city': 'San Francisco, CA',
      'address': '3055 17th St, San Francisco, CA 94110',
      'phone': '+1 415-641-8222',
      'website': 'https://sfjudo.org',
      'disciplines': ['judo'],
      'dropInFee': 20,
      'rating': 4.7,
      'latitude': 37.76354,
      'longitude': -122.41367,
      'membershipOptions': [
        'Adult program - \$95/mo',
        'Youth program - \$65/mo',
      ],
    },
    {
      'name': 'Bay Area Wrestling Club',
      'city': 'Fremont, CA',
      'address': '40909 Encyclopedia Cir, Fremont, CA 94538',
      'phone': '+1 510-589-0097',
      'website': 'https://bayareawrestlingclub.com',
      'disciplines': ['wrestling'],
      'dropInFee': 25,
      'rating': 4.6,
      'latitude': 37.5049,
      'longitude': -121.9664,
      'membershipOptions': [
        'Season pass - \$180',
        'Mat club drop-in - \$25',
      ],
    },
    {
      'name': 'US Taekwondo Academy Daly City',
      'city': 'Daly City, CA',
      'address': '6235 Mission St, Daly City, CA 94014',
      'phone': '+1 650-878-0800',
      'website': 'https://ustkdacademy.com',
      'disciplines': ['tae kwon do'],
      'dropInFee': 20,
      'rating': 4.8,
      'latitude': 37.70862,
      'longitude': -122.45436,
      'membershipOptions': [
        'Unlimited TKD - \$165/mo',
        'Family plan - \$299/mo',
      ],
    },
    {
      'name': 'Third Street Boxing Gym',
      'city': 'San Francisco, CA',
      'address': '2576 3rd St, San Francisco, CA 94107',
      'phone': '+1 415-757-0818',
      'website': 'https://thirdstreetboxing.com',
      'disciplines': ['boxing', 'conditioning'],
      'dropInFee': 30,
      'rating': 4.7,
      'latitude': 37.75564,
      'longitude': -122.38848,
      'membershipOptions': [
        'Unlimited boxing - \$175/mo',
        '10-class pack - \$220',
      ],
    },
    {
      'name': 'Fairtex Training Center',
      'city': 'San Francisco, CA',
      'address': '444 Clementina St, San Francisco, CA 94103',
      'phone': '+1 415-777-5887',
      'website': 'https://fairtex.com/san-francisco',
      'disciplines': ['muay thai', 'mma', 'bjj'],
      'dropInFee': 30,
      'rating': 4.8,
      'latitude': 37.78141,
      'longitude': -122.40412,
      'membershipOptions': [
        'All access - \$209/mo',
        'Striking only - \$169/mo',
      ],
    },
  ];

  Future<List<Gym>> fetchGyms({
    String? query,
    String? discipline,
    LatLng? userLocation,
  }) async {
    try {
      Query<Map<String, dynamic>> gymsQuery = _firestore.collection('gyms');

      if (discipline != null && discipline.isNotEmpty && discipline != 'all') {
        gymsQuery = gymsQuery.where('disciplines',
            arrayContains: discipline.toLowerCase());
      }

      final snapshot = await gymsQuery.limit(50).get();

      if (snapshot.docs.isEmpty) {
        await _seedGyms();
        final seededSnapshot =
            await _firestore.collection('gyms').limit(50).get();
        return _mapGyms(seededSnapshot,
            query: query, userLocation: userLocation);
      }

      return _mapGyms(snapshot, query: query, userLocation: userLocation);
    } catch (e) {
      debugPrint('Failed to load gyms: $e');
      return <Gym>[];
    }
  }

  List<Gym> _mapGyms(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    String? query,
    LatLng? userLocation,
  }) {
    final lowerQuery = query?.trim().toLowerCase();
    final gyms = snapshot.docs.map((doc) {
      final data = doc.data();
      final name = (data['name'] as String?)?.trim() ?? 'Gym';
      final city = (data['city'] as String?)?.trim() ?? 'Unknown city';
      final address = (data['address'] as String?)?.trim();
      final phone = (data['phone'] as String?)?.trim();
      final website = (data['website'] as String?)?.trim();
      final disciplinesRaw = data['disciplines'];
      List<String> disciplines = [];
      if (disciplinesRaw is List) {
        disciplines = disciplinesRaw
            .whereType<String>()
            .map((d) => d.trim())
            .where((d) => d.isNotEmpty)
            .toList();
      }
      final rating = (data['rating'] as num?)?.toDouble();
      final dropInFee = (data['dropInFee'] as num?)?.toDouble();

      final membershipRaw = data['membershipOptions'];
      List<String> membershipOptions = [];
      if (membershipRaw is List) {
        membershipOptions = membershipRaw
            .whereType<String>()
            .map((m) => m.trim())
            .where((m) => m.isNotEmpty)
            .toList();
      }

      final latitude = (data['latitude'] as num?)?.toDouble();
      final longitude = (data['longitude'] as num?)?.toDouble();

      double? distanceKm;
      if (userLocation != null && latitude != null && longitude != null) {
        distanceKm = _distanceInKm(
          userLocation.latitude,
          userLocation.longitude,
          latitude,
          longitude,
        );
      }

      final gym = Gym(
        id: doc.id,
        name: name,
        city: city,
        disciplines: disciplines,
        rating: rating,
        dropInFee: dropInFee,
        address: address,
        phone: phone,
        website: website,
        membershipOptions: membershipOptions,
        latitude: latitude,
        longitude: longitude,
        distanceKm: distanceKm,
      );
      return gym;
    }).where((gym) {
      if (lowerQuery == null || lowerQuery.isEmpty) {
        return true;
      }
      return gym.name.toLowerCase().contains(lowerQuery) ||
          gym.city.toLowerCase().contains(lowerQuery) ||
          gym.disciplines.any((d) => d.toLowerCase().contains(lowerQuery));
    }).toList();

    if (userLocation != null) {
      gyms.sort((a, b) {
        final aDist = a.distanceKm ?? double.infinity;
        final bDist = b.distanceKm ?? double.infinity;
        return aDist.compareTo(bDist);
      });
    }

    return gyms;
  }

  Future<void> _seedGyms() async {
    final batch = _firestore.batch();
    final gymsCollection = _firestore.collection('gyms');

    for (final gym in _defaultGyms) {
      final docRef = gymsCollection.doc();
      batch.set(
          docRef,
          {
            'name': gym['name'],
            'city': gym['city'],
            'address': gym['address'],
            'phone': gym['phone'],
            'website': gym['website'],
            'disciplines': (gym['disciplines'] as List<String>)
                .map((d) => d.toLowerCase())
                .toList(),
            'dropInFee': gym['dropInFee'],
            'rating': gym['rating'],
            'latitude': gym['latitude'],
            'longitude': gym['longitude'],
            'membershipOptions': gym['membershipOptions'],
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }

    await batch.commit();
  }
}

class Gym {
  Gym({
    required this.id,
    required this.name,
    required this.city,
    required this.disciplines,
    this.rating,
    this.dropInFee,
    this.address,
    this.phone,
    this.website,
    this.membershipOptions = const [],
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String city;
  final List<String> disciplines;
  final double? rating;
  final double? dropInFee;
  final String? address;
  final String? phone;
  final String? website;
  final List<String> membershipOptions;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
}

class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

double _distanceInKm(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusKm = 6371;
  final double dLat = _deg2rad(lat2 - lat1);
  final double dLon = _deg2rad(lon2 - lon1);
  final double a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);
