import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumblr/features/rankings/screens/rankings_screen.dart';

void main() {
  testWidgets('RankingsScreen loads weight classes, remembers last selection, and persists updates',
      (tester) async {
    final requestedWeightClasses = <String>[];
    String? savedWeightClass;
    int weightClassesLoadCount = 0;

    Future<List<Map<String, dynamic>>> fakeRankingsLoader(String weightClass) async {
      requestedWeightClasses.add(weightClass);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return [
        {
          'username': 'Fighter $weightClass',
          'eloRatings': {weightClass: 1675},
        },
      ];
    }

    Future<List<String>> fakeWeightClassesLoader() async {
      weightClassesLoadCount++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return const ['mma', 'welterweight'];
    }

    Future<String?> fakeLastWeightClassLoader() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return 'welterweight';
    }

    Future<void> fakeLastWeightClassSaver(String weightClass) async {
      savedWeightClass = weightClass;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: RankingsScreen(
          weightClasses: const ['mma', 'welterweight'],
          loadRankings: fakeRankingsLoader,
          loadWeightClasses: fakeWeightClassesLoader,
          loadLastWeightClass: fakeLastWeightClassLoader,
          saveLastWeightClass: fakeLastWeightClassSaver,
        ),
      ),
    );

    // Initial pump should show a loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(weightClassesLoadCount, 1);
    expect(requestedWeightClasses.first, 'welterweight');
    expect(savedWeightClass, 'welterweight');
    expect(find.text('Fighter welterweight'), findsOneWidget);

    await tester.tap(find.byKey(const Key('weight-class-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('mma').last);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(requestedWeightClasses.last, 'mma');
    expect(savedWeightClass, 'mma');
    expect(find.text('Fighter mma'), findsOneWidget);
  });
}
