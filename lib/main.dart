import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config.dart';
import 'i18n.dart';
import 'state.dart';
import 'theme.dart';
import 'firebase_options.dart';
import 'data/supabase/sb_client.dart';
import 'services/sound.dart';
import 'screens/auth_screen.dart';
import 'screens/client_screen.dart';
import 'screens/driver_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kUseSupabase) {
    await initSupabase();
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await loadLang();
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
    final authReady = context.select<AppState, bool>((s) => s.authReady);
    final signedIn = context.select<AppState, bool>((s) => s.uid != null);
    final profileLoaded = context.select<AppState, bool>((s) => s.profileLoaded);
    final hasName = context.select<AppState, bool>((s) => s.userName.isNotEmpty);
    const loading = Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF111317)),
      ),
    );
    // Смена языка перестраивает приложение (см. setLang в i18n.dart).
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => MaterialApp(
      title: kBrand,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      builder: (context, child) => Listener(
        onPointerDown: (_) => unlockSound(),
        child: child,
      ),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: !authReady
          ? loading
          : !signedIn
              ? const AuthScreen()
              : !profileLoaded
                  ? loading
                  : !hasName
                      ? const AuthScreen(key: ValueKey('name'), nameOnly: true)
                      : isDriverMode
                          ? const DriverScreen()
                          : const ClientScreen(),
      ),
    );
  }
}
