import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nirbhay_flutter/providers/app_providers.dart';
import 'package:nirbhay_flutter/screens/dashboard/dashboard_screen.dart';
import 'package:nirbhay_flutter/screens/onboarding_screen.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Lock orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Initialize online presence on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeOnlinePresence();
    });
  }

  @override
  void dispose() {
    // Unregister observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final firebaseLocationService = ref.read(firebaseLocationServiceProvider);

    // Update online status based on app lifecycle
    switch (state) {
      case AppLifecycleState.resumed:
        // App in foreground
        _initializeOnlinePresence();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App in background or closed
        firebaseLocationService.setUserOffline();
        break;
    }
  }

  Future<void> _initializeOnlinePresence() async {
    final authState = ref.read(authStateProvider);
    if (authState.isAuthenticated) {
      // Set up online presence for authenticated users
      await ref.read(firebaseLocationServiceProvider).setupOnlinePresence();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Nirbhay Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home:
          authState.isAuthenticated
              ? const DashboardScreen()
              : const OnboardingScreen(),
    );
  }
}
