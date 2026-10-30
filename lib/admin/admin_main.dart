import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../firebase_options.dart';
import '../screens/auth_screen.dart';
import '../state.dart';
import '../theme.dart';
import 'places_page.dart';
import 'regions_page.dart';
import 'tariffs_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(ChangeNotifierProvider(
    create: (_) => AppState(),
    child: const AdminApp(),
  ));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final profileLoaded = context.select<AppState, bool>((s) => s.profileLoaded);
    final hasName = context.select<AppState, bool>((s) => s.userName.isNotEmpty);
    final isAdmin = context.select<AppState, bool>((s) => s.isAdmin);
    return MaterialApp(
      title: 'DOSTYQ TAXI · Админ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          const loading = Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF0E7C66))),
          );
          if (snap.connectionState == ConnectionState.waiting) return loading;
          if (snap.data == null) return const AuthScreen();
          if (!profileLoaded) return loading;
          if (!hasName) return const AuthScreen(nameOnly: true);
          if (!isAdmin) return const _NoAccess();
          return const AdminHome();
        },
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: context.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: context.taxi, size: 40),
                const SizedBox(height: 16),
                Text('Нет доступа к админке',
                    style: TextStyle(
                      color: context.ink, fontSize: 26, fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 8),
                Text(
                  'Этот номер (${user?.phoneNumber ?? ''}) — обычный клиент. '
                  'Админ должен поставить ему роль «admin» в базе: '
                  'Firestore → users → документ этого пользователя → поле role.',
                  style: TextStyle(color: context.muted, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 8),
                SelectableText('ID пользователя: ${user?.uid ?? ''}',
                    style: TextStyle(color: context.muted, fontSize: 13)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => context.read<AppState>().reloadProfile(),
                      child: const Text('Проверить снова'),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Выйти'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _page = 0;

  static const _pages = [
    (Icons.tune_rounded, 'Тарифы'),
    (Icons.place_outlined, 'Места'),
    (Icons.location_city_rounded, 'Районы'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final body = switch (_page) {
      0 => const TariffsPage(),
      1 => const PlacesPage(),
      _ => const RegionsPage(),
    };
    final name = context.select<AppState, String>((s) => s.userName);

    if (!wide) {
      return Scaffold(
        backgroundColor: context.bg,
        appBar: AppBar(
          title: Text(_pages[_page].$2),
          actions: [
            const _RegionPicker(),
            IconButton(
              tooltip: 'Выйти',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ],
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _page,
          onDestinationSelected: (i) => setState(() => _page = i),
          destinations: [
            for (final (icon, label) in _pages)
              NavigationDestination(icon: Icon(icon), label: label),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.bg,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _page,
            onDestinationSelected: (i) => setState(() => _page = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text('DOSTYQ', style: TextStyle(
                    color: context.taxi, fontWeight: FontWeight.w800, fontSize: 13,
                  )),
                  Text('админ', style: TextStyle(color: context.muted, fontSize: 12)),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: TextStyle(color: context.muted, fontSize: 12)),
                      IconButton(
                        tooltip: 'Выйти',
                        icon: const Icon(Icons.logout_rounded),
                        onPressed: () => FirebaseAuth.instance.signOut(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: [
              for (final (icon, label) in _pages)
                NavigationRailDestination(icon: Icon(icon), label: Text(label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: context.paper,
                  child: Row(
                    children: [
                      Text('Район:', style: TextStyle(color: context.muted, fontSize: 14)),
                      const SizedBox(width: 10),
                      const _RegionPicker(),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Район, с которым сейчас работает админ: цены и места показываются для него.
class _RegionPicker extends StatelessWidget {
  const _RegionPicker();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return DropdownButton<String>(
      value: state.regionId,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(12),
      items: [
        for (final r in state.allRegions)
          DropdownMenuItem(
            value: r.id,
            child: Text(r.active ? r.name : '${r.name} (выкл.)',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
      onChanged: (id) {
        if (id != null) state.setRegion(id, movePickup: false);
      },
    );
  }
}