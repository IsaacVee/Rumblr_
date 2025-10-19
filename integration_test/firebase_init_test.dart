import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rumblr/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Firebase configuration', () {
    testWidgets('initializes the default Firebase app', (tester) async {
      FirebaseApp app;

      if (Firebase.apps.isEmpty) {
        app = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        app = Firebase.app();
      }

      expect(app.options.projectId, 'rumblr-f8c63');
    });

    testWidgets('macOS builds use macOS Firebase options', (tester) async {
      final firebaseOptions = DefaultFirebaseOptions.currentPlatform;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
        expect(firebaseOptions.appId, DefaultFirebaseOptions.macos.appId);
        expect(firebaseOptions.apiKey, DefaultFirebaseOptions.macos.apiKey);
      }
    });
  });
}
