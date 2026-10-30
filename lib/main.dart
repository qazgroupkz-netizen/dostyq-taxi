import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config.dart';
import 'state.dart';
import 'theme.dart';
import 'firebase_options.dart';
import 'services/sound.dart';
import 'screens/auth_screen.dart';
import 'screens/client_screen.dart';
import 'screens/driver_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const DostyqApp(),
    ),
  );
}

class DostyqApp extends StatelessWidget {
  const DostyqApp({super.key});

  @override
  Widget build(BuildContext context) {
    // select, а не watch: иначе каждое движение карты перестраивает всё приложение.
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    final isDriverMode = context.select<AppState, bool>((s) => s.isDriverMode);
    final profileLoaded = context.select<AppState, bool>((s) => s.profileLoaded);
    final hasName = context.select<AppState, bool>((s) => s.userName.isNotEmpty);
    return MaterialApp(
      title: kBrand,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      builder: (context, child) => Listener(
        onPointerDown: (_) => unlockSound(),
        child: child,
      ),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          const loading = Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0E7C66)),
            ),
          );
          if (snap.connectionState == ConnectionState.waiting) return loading;
          if (snap.data == null) return const AuthScreen();
          if (!profileLoaded) return loading;
          if (!hasName) return const AuthScreen(nameOnly: true);
          return isDriverMode
              ? const DriverScreen()
              : const ClientScreen();
        },
      ),
    );
  }
}
