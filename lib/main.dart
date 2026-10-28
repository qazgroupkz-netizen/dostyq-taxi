import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'state.dart';
import 'theme.dart';
import 'firebase_options.dart';
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
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'DOSTYQ TAXI',
      debugShowCheckedModeBanner: false,
      themeMode: state.themeMode,
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
          if (!state.profileLoaded) return loading;
          if (state.userName.isEmpty) return const AuthScreen(nameOnly: true);
          return state.isDriverMode
              ? const DriverScreen()
              : const ClientScreen();
        },
      ),
    );
  }
}
