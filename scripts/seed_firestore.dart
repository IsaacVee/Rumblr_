import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rumblr/firebase_options.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final bool dryRun = args.contains('--dry-run');

  final String? projectId = env['FIREBASE_PROJECT_ID'];
  if (projectId == null) {
    stderr.writeln('FIREBASE_PROJECT_ID env var required.');
    exitCode = 1;
    return;
  }

  stdout.writeln('Initializing Firebase for project $projectId');
  final options = _resolveFirebaseOptions(env, projectId);
  try {
    await Firebase.initializeApp(options: options);
  } on UnsupportedError catch (e) {
    stderr.writeln('Failed to initialize Firebase. ${e.message}');
    exitCode = 1;
    return;
  }
  final firestore = FirebaseFirestore.instance;

  if (dryRun) {
    stdout.writeln('Running in dry-run mode. No writes will be committed.');
  }

  await _seedFighters(firestore, dryRun);
  await _seedEvents(firestore, dryRun);
  await _seedHighlights(firestore, dryRun);

  stdout.writeln('Seeding completed${dryRun ? ' (dry run)' : ''}.');
}

Future<void> _seedFighters(FirebaseFirestore firestore, bool dryRun) async {
  stdout.writeln('Seeding fighters...');
  final fighters = [
    {
      'id': 'demo-fighter-1',
      'username': 'Ana Lucia',
      'email': 'ana@example.com',
      'eloRatings': {
        'mma': 1660,
        'bjj': 1550,
      },
      'primaryWeightClass': 'mma',
      'record': {'wins': 12, 'losses': 3},
    },
    {
      'id': 'demo-fighter-2',
      'username': 'Jamal Reeves',
      'email': 'jamal@example.com',
      'eloRatings': {
        'mma': 1625,
        'muay thai': 1480,
      },
      'primaryWeightClass': 'mma',
      'record': {'wins': 9, 'losses': 2},
    },
    {
      'id': 'demo-fighter-3',
      'username': 'Mia Park',
      'email': 'mia@example.com',
      'eloRatings': {
        'mma': 1580,
        'wrestling': 1510,
      },
      'primaryWeightClass': 'mma',
      'record': {'wins': 7, 'losses': 4},
    },
  ];

  for (final fighter in fighters) {
    final docRef = firestore.collection('fighters').doc(fighter['id'] as String);
    stdout.writeln(' - ${fighter['username']} (${fighter['id']})');
    if (!dryRun) {
      await docRef.set({
        'username': fighter['username'],
        'email': fighter['email'],
        'eloRatings': fighter['eloRatings'],
        'primaryWeightClass': fighter['primaryWeightClass'],
        'record': fighter['record'],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}

FirebaseOptions _resolveFirebaseOptions(Map<String, String> env, String projectId) {
  final apiKey = env['FIREBASE_API_KEY'];
  final appId = env['FIREBASE_APP_ID'];
  final messagingSenderId = env['FIREBASE_MESSAGING_SENDER_ID'];
  final storageBucket = env['FIREBASE_STORAGE_BUCKET'];

  if (apiKey != null && appId != null && messagingSenderId != null) {
    stdout.writeln('Using FirebaseOptions from environment variables.');
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
    );
  }

  stdout.writeln('Using DefaultFirebaseOptions for initialization.');
  try {
    return DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    stderr.writeln('DefaultFirebaseOptions not configured for this platform.');
    rethrow;
  }
}

Future<void> _seedEvents(FirebaseFirestore firestore, bool dryRun) async {
  stdout.writeln('Seeding events...');
  final now = DateTime.now();
  final events = [
    {
      'title': 'Brooklyn Invitational',
      'date': now.add(const Duration(days: 7)),
      'location': 'BKLYN Fight Club',
      'description': 'MMA invitational featuring top prospects.',
    },
    {
      'title': 'Queens Grapple Fest',
      'date': now.add(const Duration(days: 14)),
      'location': 'Queens MMA Collective',
      'description': 'Sub-only grappling showcase for NYC talent.',
    },
  ];

  for (final event in events) {
    stdout.writeln(' - ${event['title']}');
    if (!dryRun) {
      await firestore.collection('events').add({
        'title': event['title'],
        'date': Timestamp.fromDate(event['date'] as DateTime),
        'location': event['location'],
        'description': event['description'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

Future<void> _seedHighlights(FirebaseFirestore firestore, bool dryRun) async {
  stdout.writeln('Seeding highlights...');
  final highlights = [
    {
      'title': 'Ana Lucia extends win streak',
      'detail': 'Earned a submission victory in round two.',
      'author': 'Rumblr Bot',
    },
    {
      'title': 'Jamal Reeves cracks top 5',
      'detail': 'Big decision win vaults him up the ladder.',
      'author': 'Rumblr Bot',
    },
  ];

  for (final highlight in highlights) {
    stdout.writeln(' - ${highlight['title']}');
    if (!dryRun) {
      await firestore.collection('highlights').add({
        'title': highlight['title'],
        'detail': highlight['detail'],
        'author': highlight['author'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
