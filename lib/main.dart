import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'package:rumblr/core/constants/app_routes.dart';
import 'package:rumblr/core/services/notification_service.dart';
import 'package:rumblr/features/auth/screens/login_screen.dart';
import 'package:rumblr/features/auth/screens/register_screen.dart';
import 'package:rumblr/features/fights/screens/fights_screen.dart';
import 'package:rumblr/features/fights/screens/log_fight_screen.dart';
import 'package:rumblr/features/gyms/screens/gym_search_screen.dart';
import 'package:rumblr/features/home/screens/home_screen.dart';
import 'package:rumblr/features/rankings/screens/rankings_screen.dart';
import 'package:rumblr/features/tournaments/screens/tournament_detail_screen.dart';
import 'package:rumblr/features/tournaments/screens/tournaments_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;
  Object? initializationError;
  StackTrace? initializationStackTrace;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
  } catch (error, stackTrace) {
    initializationError = error;
    initializationStackTrace = stackTrace;
    debugPrint('Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  if (firebaseInitialized && !kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService.initialize();
  }

  runApp(
    RumblrApp(
      firebaseInitialized: firebaseInitialized,
      initializationError: initializationError,
      initializationStackTrace: initializationStackTrace,
    ),
  );
}

class RumblrApp extends StatelessWidget {
  final bool firebaseInitialized;
  final Object? initializationError;
  final StackTrace? initializationStackTrace;

  const RumblrApp({
    super.key,
    required this.firebaseInitialized,
    this.initializationError,
    this.initializationStackTrace,
  });

  @override
  Widget build(BuildContext context) {
    final bool firebaseReady = firebaseInitialized && Firebase.apps.isNotEmpty;
    final User? initialUser =
        firebaseReady ? FirebaseAuth.instance.currentUser : null;
    final Stream<User?> authChanges = firebaseReady
        ? FirebaseAuth.instance.authStateChanges()
        : Stream<User?>.value(initialUser);

    // If Firebase failed to initialize, show error screen
    if (!firebaseInitialized) {
      return MaterialApp(
        title: 'Rumblr',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: FirebaseErrorScreen(
          error: initializationError,
          stackTrace: initializationStackTrace,
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: authChanges,
      initialData: initialUser,
      builder: (context, snapshot) {
        final User? user = snapshot.data;
        final Widget home =
            user == null ? const LoginScreen() : const HomeScreen();

        return MaterialApp(
          title: 'Rumblr',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
            useMaterial3: true,
          ),
          debugShowCheckedModeBanner: false,
          home: home,
          onGenerateRoute: (settings) => _AuthRouteGuard.resolve(settings,
              user: user, firebaseInitialized: firebaseInitialized),
        );
      },
    );
  }
}

class _AuthRouteGuard {
  static const Set<String> _publicRoutes = <String>{
    AppRoutes.login,
    AppRoutes.register,
  };

  static const Set<String> _protectedRoutes = <String>{
    AppRoutes.home,
    AppRoutes.rankings,
    AppRoutes.logFight,
    AppRoutes.gymSearch,
    AppRoutes.fights,
    AppRoutes.tournaments,
    AppRoutes.tournamentDetail,
  };

  static Route<dynamic> resolve(RouteSettings settings,
      {required User? user, required bool firebaseInitialized}) {
    final bool firebaseReady = firebaseInitialized && Firebase.apps.isNotEmpty;
    final bool isAuthenticated = user != null ||
        (firebaseReady && FirebaseAuth.instance.currentUser != null);
    final String requestedName = settings.name ?? AppRoutes.login;
    final String effectiveName = requestedName == '/'
        ? (isAuthenticated ? AppRoutes.home : AppRoutes.login)
        : requestedName;

    if (!isAuthenticated &&
        _protectedRoutes.contains(effectiveName) &&
        !(kDebugMode && effectiveName == AppRoutes.home)) {
      return MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
        settings: const RouteSettings(name: AppRoutes.login),
      );
    }

    if (isAuthenticated && _publicRoutes.contains(effectiveName)) {
      return MaterialPageRoute<void>(
        builder: (_) => const HomeScreen(),
        settings: const RouteSettings(name: AppRoutes.home),
      );
    }

    final _RouteBuilder? builder = _routeBuilders[effectiveName];
    if (builder != null) {
      return MaterialPageRoute<void>(
        builder: (context) => builder(context, settings),
        settings:
            RouteSettings(name: effectiveName, arguments: settings.arguments),
      );
    }

    final Widget fallback =
        isAuthenticated ? const HomeScreen() : const LoginScreen();
    final String fallbackName =
        isAuthenticated ? AppRoutes.home : AppRoutes.login;
    return MaterialPageRoute<void>(
      builder: (_) => fallback,
      settings:
          RouteSettings(name: fallbackName, arguments: settings.arguments),
    );
  }

  static final Map<String, _RouteBuilder> _routeBuilders =
      <String, _RouteBuilder>{
    AppRoutes.login: (context, _) => const LoginScreen(),
    AppRoutes.register: (context, _) => const RegisterScreen(),
    AppRoutes.home: (context, _) => const HomeScreen(),
    AppRoutes.rankings: (context, _) => const RankingsScreen(),
    AppRoutes.logFight: (context, _) => const LogFightScreen(),
    AppRoutes.gymSearch: (context, _) => const GymSearchScreen(),
    AppRoutes.fights: (context, _) => const FightsScreen(),
    AppRoutes.tournaments: (context, _) => const TournamentsScreen(),
    AppRoutes.tournamentDetail: (context, _) => const TournamentDetailScreen(),
  };
}

typedef _RouteBuilder = Widget Function(
    BuildContext context, RouteSettings settings);

class FirebaseErrorScreen extends StatelessWidget {
  final Object? error;
  final StackTrace? stackTrace;

  const FirebaseErrorScreen({
    super.key,
    this.error,
    this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    final String? errorDescription = error?.toString();
    final String? stackTraceDescription = stackTrace?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Rumblr - Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Firebase Initialization Failed',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to connect to Firebase services. Please check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              if (errorDescription != null) ...[
                const SizedBox(height: 24),
                SelectableText(
                  'Error: $errorDescription',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
              if (stackTraceDescription != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  stackTraceDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'If this problem persists, please contact support.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
