import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/auth.dart';
import '../data/drivers.dart';
import '../data/supabase/sb_client.dart';
import '../data/orders.dart';
import '../firebase_options.dart';
import '../services/sound.dart';
import '../screens/auth_screen.dart';
import '../config.dart';
import '../state.dart';
import '../theme.dart';
import 'admin_ui.dart';
import 'analytics_page.dart';
import 'dispatch_page.dart';
import 'drivers_page.dart';
import 'finance_page.dart';
import 'intercity_page.dart';
import 'migrate_page.dart';
import 'orders_page.dart';
import 'places_page.dart';
import 'regions_page.dart';
import 'streets_page.dart';
import 'tariffs_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kUseSupabase) {
    await initSupabase();
  } else {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(ChangeNotifierProvider(
    create: (_) => AppState(),
    child: const AdminApp(),
  ));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authReady = context.select<AppState, bool>((s) => s.authReady);
    final signedIn = context.select<AppState, bool>((s) => s.uid != null);
    final profileLoaded = context.select<AppState, bool>((s) => s.profileLoaded);
    final hasName = context.select<AppState, bool>((s) => s.userName.isNotEmpty);
    final isAdmin = context.select<AppState, bool>((s) => s.isAdmin);
    const loading = Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFF111317))),
    );
    return MaterialApp(
      title: '$kBrand · Админ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.admin(),
      builder: (context, child) => Listener(
        onPointerDown: (_) => unlockSound(),
        child: child,
      ),
      home: !authReady
          ? loading
          : !signedIn
              ? const AuthScreen()
              : !profileLoaded
                  ? loading
                  : !hasName
                      ? const AuthScreen(key: ValueKey('name'), nameOnly: true)
                      : !isAdmin
                          ? const _NoAccess()
                          : const AdminHome(),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) {
    final user = authRepo.current;
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
                Icon(Icons.lock_outline_rounded, color: context.accent, size: 40),
                const SizedBox(height: 16),
                Text('Нет доступа к админке',
                    style: TextStyle(
                      color: context.ink, fontSize: 26, fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 8),
                Text(
                  'Этот номер (${user?.phone ?? ''}) — обычный клиент. '
                  'Админ должен поставить ему роль «admin» в базе: '
                  '${kUseSupabase ? 'таблица profiles' : 'Firestore → users'} → '
                  'запись этого пользователя → поле role.',
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
                      onPressed: () => authRepo.signOut(),
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

/// Пункт меню: группа, значок, название, страница, только для админа.
typedef _Nav = ({String group, IconData icon, String label, Widget page, bool ownerOnly});

class _AdminHomeState extends State<AdminHome> {
  int _page = 0;
  Timer? _clock;

  // Порядок и группы — как в reference/admin-prototype.html.
  static final _all = <_Nav>[
    (group: 'Обзор', icon: Icons.bar_chart_rounded, label: 'Аналитика',
        page: const AnalyticsPage(), ownerOnly: true),
    (group: 'Обзор', icon: Icons.attach_money_rounded, label: 'Финансы',
        page: const FinancePage(), ownerOnly: true),
    (group: 'Оперативно', icon: Icons.headset_mic_outlined, label: 'Диспетчерская',
        page: const DispatchPage(), ownerOnly: false),
    (group: 'Оперативно', icon: Icons.format_list_bulleted_rounded, label: 'Заказы',
        page: const OrdersPage(), ownerOnly: false),
    (group: 'Оперативно', icon: Icons.domain_rounded, label: 'Межгород',
        page: const IntercityPage(), ownerOnly: false),
    (group: 'Водители', icon: Icons.group_outlined, label: 'Водители',
        page: const DriversPage(), ownerOnly: true),
    (group: 'Настройки', icon: Icons.place_outlined, label: 'Адреса',
        page: PlacesPage(), ownerOnly: true),
    (group: 'Настройки', icon: Icons.signpost_outlined, label: 'Улицы',
        page: StreetsPage(), ownerOnly: true),
    (group: 'Настройки', icon: Icons.tune_rounded, label: 'Тарифы и правила',
        page: TariffsPage(), ownerOnly: true),
    (group: 'Настройки', icon: Icons.location_city_rounded, label: 'Районы',
        page: RegionsPage(), ownerOnly: true),
    // Перенос справочников в свою базу — только в админке на Firebase.
    if (!kUseSupabase)
      (group: 'Настройки', icon: Icons.cloud_upload_outlined, label: 'Перенос в новую базу',
          page: const MigratePage(), ownerOnly: true),
  ];

  late final Stream<List<DriverProfile>> _drivers = context.read<AppState>().drivers.watchAll();
  Stream<List<TaxiOrder>>? _orders;
  String? _region;

  @override
  void initState() {
    super.initState();
    // Часы в шапке и счётчик «ждут водителя».
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_region != state.regionId) {
      _region = state.regionId;
      _orders = state.orders.watchRegion(state.regionId);
    }
    final wide = MediaQuery.of(context).size.width >= 900;
    final isOwner = state.role == 'admin';
    final pages = [for (final p in _all) if (isOwner || !p.ownerOnly) p];
    if (_page >= pages.length) _page = 0;

    return StreamBuilder<List<DriverProfile>>(
      stream: _drivers,
      builder: (context, dSnap) => StreamBuilder<List<TaxiOrder>>(
        stream: _orders,
        builder: (context, oSnap) {
          final pending = (dSnap.data ?? const <DriverProfile>[])
              .where((d) => d.region == state.regionId && d.approval == Approval.pending)
              .length;
          final waiting =
              (oSnap.data ?? const <TaxiOrder>[]).where((o) => o.status == 'searching').length;
          final counts = {'Диспетчерская': waiting, 'Водители': pending};
          void go(String label) {
            final i = pages.indexWhere((p) => p.label == label);
            if (i >= 0) setState(() => _page = i);
          }

          final side = _Sidebar(
            pages: pages,
            selected: _page,
            counts: counts,
            drivers: [
              for (final d in dSnap.data ?? const <DriverProfile>[])
                if (d.region == state.regionId) d,
            ],
            onSelect: (i) {
              setState(() => _page = i);
              if (!wide) Navigator.of(context).maybePop();
            },
          );
          final content = Column(
            children: [
              _Header(
                wide: wide,
                alerts: waiting + pending,
                onSearch: (q) {
                  adminSearch.value = q;
                  go('Заказы');
                },
                onBell: () => go(waiting > 0 || pending == 0 ? 'Диспетчерская' : 'Водители'),
              ),
              Expanded(child: pages[_page].page),
            ],
          );

          if (wide) {
            return Scaffold(
              backgroundColor: AdminC.bg,
              body: Row(children: [side, Expanded(child: content)]),
            );
          }
          return Scaffold(
            backgroundColor: AdminC.bg,
            drawer: Drawer(width: 248, backgroundColor: AdminC.side, child: side),
            body: content,
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<_Nav> pages;
  final int selected;
  final Map<String, int> counts;
  final List<DriverProfile> drivers;
  final ValueChanged<int> onSelect;
  const _Sidebar({
    required this.pages,
    required this.selected,
    required this.counts,
    required this.drivers,
    required this.onSelect,
  });

  /// Карточка «Подписки водителей»: сколько одобренных водителей с активной подпиской.
  Widget _subsCard() {
    final approved = drivers.where((d) => d.approval == Approval.approved).toList();
    final active = approved.where((d) => d.subscriptionActive).length;
    final soon = approved.where((d) => (d.subscriptionDaysLeft ?? 99) <= 3 && d.subscriptionActive).length;
    final share = approved.isEmpty ? 0.0 : active / approved.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 14, 6, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF262A31), Color(0xFF17191E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Подписки водителей',
              style: TextStyle(color: AdminC.sideMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('$active из ${approved.length}',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              backgroundColor: const Color(0xFF2E323A),
              color: AdminC.yellow,
            ),
          ),
          const SizedBox(height: 8),
          Text(soon > 0 ? 'Заканчивается у $soon — напомните' : 'Активны и оплачены',
              style: const TextStyle(color: AdminC.sideMuted, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<AppState, String>((s) => s.userName);
    final items = <Widget>[];
    String? group;
    for (var i = 0; i < pages.length; i++) {
      final p = pages[i];
      if (p.group != group) {
        group = p.group;
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
          child: Text(p.group.toUpperCase(),
              style: const TextStyle(
                color: AdminC.sideMuted, fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: .9,
              )),
        ));
      }
      final active = i == selected;
      final count = counts[p.label] ?? 0;
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: active ? AdminC.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            hoverColor: AdminC.side2,
            onTap: () => onSelect(i),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(p.icon, size: 20, color: active ? AdminC.ink : AdminC.sideText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(p.label,
                        style: TextStyle(
                          color: active ? AdminC.ink : AdminC.sideText,
                          fontSize: 14.5, fontWeight: FontWeight.w600,
                        )),
                  ),
                  if (count > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: active ? AdminC.ink : AdminC.bad,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text('$count',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800,
                          )),
                    ),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    return Container(
      width: 248,
      color: AdminC.side,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 6),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AdminC.yellow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_taxi_rounded, color: AdminC.ink, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kBrand,
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('Админ-панель',
                          style: TextStyle(color: AdminC.sideMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _RegionPicker(),
              Expanded(
                child: ListView(children: [
                  ...items,
                  if (pages.any((p) => p.ownerOnly)) _subsCard(),
                ]),
              ),
              const Divider(color: AdminC.side2),
              Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AdminC.sideText, fontSize: 13)),
                  ),
                  IconButton(
                    tooltip: 'Выйти',
                    icon: const Icon(Icons.logout_rounded, color: AdminC.sideText, size: 20),
                    onPressed: () => authRepo.signOut(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Шапка: приветствие, дата и время, район; справа — значок пользователя.
class _Header extends StatelessWidget {
  final bool wide;
  final int alerts;
  final ValueChanged<String> onSearch;
  final VoidCallback onBell;
  const _Header({required this.wide, required this.alerts, required this.onSearch, required this.onBell});

  Widget _bell(BuildContext context) => Material(
        color: context.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.lineC),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onBell,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_none_rounded, color: context.ink, size: 22),
                if (alerts > 0)
                  Positioned(
                    top: 8,
                    right: 9,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AdminC.bad,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.paper, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  static const _days = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
  static const _months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля',
      'августа', 'сентября', 'октября', 'ноября', 'декабря'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final hello = now.hour < 5
        ? 'Доброй ночи'
        : now.hour < 12
            ? 'Доброе утро'
            : now.hour < 18
                ? 'Добрый день'
                : 'Добрый вечер';
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 8, 14, wide ? 28 : 16, 4),
        child: Row(
          children: [
            if (!wide)
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$hello${state.userName.isEmpty ? '' : ', ${state.userName}'}',
                      style: const TextStyle(color: AdminC.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                    '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} · $time · ${state.region.name}',
                    style: TextStyle(color: context.muted, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (wide) ...[
              SizedBox(
                width: 300,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.lineC),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: context.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onSubmitted: onSearch,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(color: context.ink, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Поиск: заказ, водитель, телефон',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            _bell(context),
            const SizedBox(width: 12),
            Container(
              width: 42, height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD12E), Color(0xFFFFB020)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.userName.isEmpty ? 'А' : state.userName.characters.first.toUpperCase(),
                style: const TextStyle(color: AdminC.ink, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Район, с которым сейчас работает админ: всё в админке показывается для него.
class _RegionPicker extends StatelessWidget {
  const _RegionPicker();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminC.side2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: state.regionId,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AdminC.side2,
        iconEnabledColor: AdminC.sideText,
        borderRadius: BorderRadius.circular(12),
        items: [
          for (final r in state.allRegions)
            DropdownMenuItem(
              value: r.id,
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(r.active ? r.name : '${r.name} (выкл.)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
        onChanged: (id) {
          if (id != null) state.setRegion(id, movePickup: false);
        },
      ),
    );
  }
}