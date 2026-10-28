import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../state.dart';
import '../theme.dart';
import '../widgets/mock_map.dart';
import '../widgets/car_svgs.dart';
import 'search_screen.dart';

// ════════════════════════════════════════════════════════════════
//  Главный экран клиента
// ════════════════════════════════════════════════════════════════
class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});
  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      key: _scaffoldKey,
      drawer: _SideDrawer(onClose: () => Navigator.of(context).pop()),
      body: Stack(
        children: [
          // Карта на весь экран
          const RepaintBoundary(child: MockMap()),

          // FAB — Меню
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 14,
            child: _MapFab(
              icon: Icons.menu_rounded,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),

          // Бренд-чип по центру
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                decoration: BoxDecoration(
                  color: context.paper,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.12),
                      blurRadius: 12, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: context.taxi,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: OrnamentIcon(size: 16, color: context.onTaxi),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'DOSTYQ TAXI',
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.01 * 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // FAB — Кнопки зума (правый верх)
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            right: 14,
            child: Container(
              decoration: BoxDecoration(
                color: context.paper,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.15),
                    blurRadius: 14, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 48, height: 46,
                    child: IconButton(
                      icon: Icon(Icons.add, color: context.ink),
                      onPressed: () {},
                    ),
                  ),
                  Divider(height: 1, color: context.lineC),
                  SizedBox(
                    width: 48, height: 46,
                    child: IconButton(
                      icon: Icon(Icons.remove, color: context.ink),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),

          // FAB — Свернуть/развернуть шторку
          Positioned(
            right: 14,
            bottom: _bottomSheetHeight(state) + 14,
            child: Column(
              children: [
                _MapFab(
                  icon: state.sheetExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  onTap: () => state.toggleSheet(),
                ),
                const SizedBox(height: 8),
                _MapFab(
                  icon: Icons.my_location_rounded,
                  color: context.taxi,
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Нижняя шторка
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _BottomSheet(),
          ),
        ],
      ),
    );
  }

  double _bottomSheetHeight(AppState state) {
    if (!state.sheetExpanded) {
      return state.clientState == ClientState.home ? 130.0 : 56.0;
    }
    switch (state.clientState) {
      case ClientState.home:    return 340;
      case ClientState.seek:    return 230;
      case ClientState.coming:  return 360;
      case ClientState.arrived: return 240;
      case ClientState.ride:    return 280;
      case ClientState.rate:    return 360;
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  Нижняя шторка
// ════════════════════════════════════════════════════════════════
class _BottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if (d.primaryVelocity != null) {
          if (d.primaryVelocity! > 300) state.toggleSheet();   // свайп вниз
          if (d.primaryVelocity! < -300) {                      // свайп вверх
            if (!state.sheetExpanded) state.toggleSheet();
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: context.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.2),
              blurRadius: 40, offset: const Offset(0, -12),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          bottom: state.sheetExpanded
              ? MediaQuery.of(context).padding.bottom + 16
              : 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ручка — нажатие тоже сворачивает/разворачивает
            GestureDetector(
              onTap: () => state.toggleSheet(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(
                    color: context.line2C,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            // Панель — при свёрнутой home-шторке обрезаем до "Куда едем?"
            if (!state.sheetExpanded && state.clientState == ClientState.home)
              ClipRect(
                child: SizedBox(
                  height: 96,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: 400,
                    child: const _HomePanel(),
                  ),
                ),
              )
            else if (state.sheetExpanded)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _panelForState(state.clientState),
              ),
          ],
        ),
      ),
    );
  }

  Widget _panelForState(ClientState s) {
    switch (s) {
      case ClientState.home:    return const _HomePanel();
      case ClientState.seek:    return const _SeekPanel();
      case ClientState.coming:  return const _ComingPanel();
      case ClientState.arrived: return const _ArrivedPanel();
      case ClientState.ride:    return const _RidePanel();
      case ClientState.rate:    return const _RatePanel();
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  Панель «Главная» — выбор маршрута и тарифа
// ════════════════════════════════════════════════════════════════
class _HomePanel extends StatelessWidget {
  const _HomePanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Column(
      key: const ValueKey('home'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Строка «Откуда»
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: context.ink,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Моё местоположение',
                  style: TextStyle(
                    color: context.ink2,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: context.taxi,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text('Изменить',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
        ),

        // Поле «Куда едем?»
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SearchScreen(),
                    fullscreenDialog: true),
              );
            },
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: context.taxi,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                            color: context.taxi.withOpacity(.3),
                            blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.destination.isEmpty
                          ? 'Куда едем?'
                          : state.destination,
                      style: TextStyle(
                        color: state.destination.isEmpty
                            ? context.hint
                            : context.ink,
                        fontSize: 19,
                        fontWeight: state.destination.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w600,
                        letterSpacing: -.02 * 19,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (state.destination.isEmpty)
                    Text('',
                        style: TextStyle(color: context.muted, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),

        // Быстрые чипы
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            primary: false,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: _quickPlacesData.length,
            itemBuilder: (_, i) {
              final (label, color, icon) = _quickPlacesData[i];
              return _QuickChip(
                label: label, color: color, icon: icon,
                onTap: () => state.setDestination(label),
              );
            },
          ),
        ),

        // Тарифы
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            primary: false,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            children: Tariff.values.map((t) => _TariffCard(
              tariff: t,
              selected: state.tariff == t,
              onTap: () {
                if (t == Tariff.delivery) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Оформление доставки появится на этапе 6'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                if (t == Tariff.whole) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Рейсы в Ушарал появятся на этапе 6'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                state.setTariff(t);
              },
            )).toList(),
          ),
        ),

        // Оплата + Пожелания
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _OptButton(
                  icon: Icons.credit_card_rounded,
                  iconColor: const Color(0xFF13A35A),
                  label: state.paymentLabel,
                  onTap: () => _showPaymentSheet(context, state),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OptButton(
                  icon: Icons.notes_rounded,
                  label: 'Пожелания',
                  onTap: () => _showWishSheet(context),
                ),
              ),
            ],
          ),
        ),

        // Кнопка «Заказать»
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _CtaButton(
            label: state.destination.isEmpty
                ? 'Куда едем?'
                : 'Заказать',
            sub: state.destination.isEmpty ? null : state.tariffPrice,
            enabled: true,
            onTap: () {
              if (state.destination.isEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const SearchScreen(),
                      fullscreenDialog: true),
                );
              } else {
                state.setClientState(ClientState.seek);
                Future.delayed(const Duration(seconds: 4), () {
                  if (state.clientState == ClientState.seek) {
                    state.setClientState(ClientState.coming);
                  }
                });
              }
            },
          ),
        ),
      ],
    );
  }

  void _showPaymentSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _PaymentSheet(state: state),
      backgroundColor: Colors.transparent,
    );
  }

  void _showWishSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _WishSheet(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Панель «Ищем машину»
// ════════════════════════════════════════════════════════════════
class _SeekPanel extends StatefulWidget {
  const _SeekPanel();
  @override
  State<_SeekPanel> createState() => _SeekPanelState();
}

class _SeekPanelState extends State<_SeekPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Column(
      key: const ValueKey('seek'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Радар с анимацией
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => SizedBox(
                  width: 54, height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _Wave(progress: _ctrl.value, delay: 0),
                      _Wave(progress: _ctrl.value, delay: .5),
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          color: context.taxiSft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.directions_car,
                            color: context.taxi, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ищем машину',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 22, fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 3),
                    Text('Предлагаем заказ ближайшему водителю',
                        style: TextStyle(color: context.muted, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Индикатор прогресса
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            backgroundColor: context.surface,
            color: context.taxi,
            borderRadius: BorderRadius.circular(3),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 14),
        _TripMini(),
        const SizedBox(height: 12),
        // Кнопка отмены
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CtaButton(
            label: 'Отменить заказ',
            soft: true,
            onTap: () => state.setClientState(ClientState.home),
          ),
        ),
      ],
    );
  }
}

class _Wave extends StatelessWidget {
  final double progress, delay;
  const _Wave({required this.progress, required this.delay});

  @override
  Widget build(BuildContext context) {
    final t = ((progress + delay) % 1.0);
    return Opacity(
      opacity: (1 - t).clamp(0, .8),
      child: Container(
        width: 54 + t * 54,
        height: 54 + t * 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.taxi, width: 2),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Панель «Машина едет»
// ════════════════════════════════════════════════════════════════
class _ComingPanel extends StatefulWidget {
  const _ComingPanel();
  @override
  State<_ComingPanel> createState() => _ComingPanelState();
}
class _ComingPanelState extends State<_ComingPanel> {
  double _progress = 0.1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _progress = (_progress + .1).clamp(0, 1));
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Column(
      key: const ValueKey('coming'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Приедет через 3 мин',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 24, fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 4),
                    Text(mockDriver.car,
                        style: TextStyle(color: context.muted, fontSize: 14)),
                  ],
                ),
              ),
              _Plate(plate: mockDriver.plate),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: context.surface,
            color: context.taxi,
            borderRadius: BorderRadius.circular(3),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 14),
        _DriverRow(),
        const SizedBox(height: 12),
        _ActionRow(onCancel: () => state.setClientState(ClientState.home)),
        const SizedBox(height: 12),
        _TripMini(),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Панель «Машина на месте»
// ════════════════════════════════════════════════════════════════
class _ArrivedPanel extends StatefulWidget {
  const _ArrivedPanel();
  @override
  State<_ArrivedPanel> createState() => _ArrivedPanelState();
}
class _ArrivedPanelState extends State<_ArrivedPanel> {
  int _secs = 300;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _secs > 0) setState(() => _secs--);
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  String get _formatted {
    final m = _secs ~/ 60;
    final s = _secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Column(
      key: const ValueKey('arrived'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Машина на месте',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 24, fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 4),
                    Text(mockDriver.car,
                        style: TextStyle(color: context.muted, fontSize: 14)),
                  ],
                ),
              ),
              _Plate(plate: mockDriver.plate),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Таймер ожидания
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.taxiSft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.jLine),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Бесплатное ожидание',
                    style: TextStyle(
                      color: context.okInk,
                      fontSize: 14, fontWeight: FontWeight.w600,
                    )),
                Text(_formatted,
                    style: TextStyle(
                      color: context.okInk,
                      fontSize: 17, fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DriverRow(),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CtaButton(
            label: 'Выхожу',
            onTap: () => state.setClientState(ClientState.ride),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Панель «В пути»
// ════════════════════════════════════════════════════════════════
class _RidePanel extends StatefulWidget {
  const _RidePanel();
  @override
  State<_RidePanel> createState() => _RidePanelState();
}
class _RidePanelState extends State<_RidePanel> {
  double _progress = 0.2;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _progress = (_progress + .08).clamp(0, 1));
      if (_progress >= 1) {
        context.read<AppState>().setClientState(ClientState.rate);
      }
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('ride'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('В пути · 3 мин',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 24, fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 4),
                    Text('До места назначения',
                        style: TextStyle(color: context.muted, fontSize: 14)),
                  ],
                ),
              ),
              _Plate(plate: mockDriver.plate),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: context.surface,
            color: context.taxi,
            borderRadius: BorderRadius.circular(3),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        _TripMini(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _IconAction(icon: Icons.phone_rounded,   label: 'Водитель'),
              const SizedBox(width: 8),
              _IconAction(icon: Icons.share_rounded,   label: 'Поделиться'),
              const SizedBox(width: 8),
              _IconAction(icon: Icons.add_circle_outline, label: 'Остановка'),
              const SizedBox(width: 8),
              _IconAction(icon: Icons.shield_outlined, label: 'Помощь',
                  isRed: true),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Панель «Оценка»
// ════════════════════════════════════════════════════════════════
class _RatePanel extends StatefulWidget {
  const _RatePanel();
  @override
  State<_RatePanel> createState() => _RatePanelState();
}
class _RatePanelState extends State<_RatePanel> {
  int _stars = 0;
  final Set<int> _tags = {};

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    const tagLabels = ['Вежливый', 'Чистый салон', 'Быстро приехал', 'Аккуратно водит'];

    return Column(
      key: const ValueKey('rate'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Аватар
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
            color: context.taxiSft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(mockDriver.initial,
              style: TextStyle(
                color: context.taxi,
                fontSize: 28, fontWeight: FontWeight.w800,
              )),
        ),
        const SizedBox(height: 12),
        Text('Как прошла поездка?',
            style: TextStyle(
              color: context.ink,
              fontSize: 23, fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 4),
        Text('${state.tariffPrice} · ${state.paymentLabel}',
            style: TextStyle(color: context.muted, fontSize: 14)),
        const SizedBox(height: 14),
        // Звёзды
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => GestureDetector(
            onTap: () => setState(() => _stars = i + 1),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                _stars > i ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _stars > i ? context.gold : context.line2C,
                size: 38,
              ),
            ),
          )),
        ),
        const SizedBox(height: 12),
        // Теги
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(tagLabels.length, (i) {
              final sel = _tags.contains(i);
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) _tags.remove(i); else _tags.add(i);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? context.taxiSft : context.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: sel ? context.jLine : Colors.transparent,
                    ),
                  ),
                  child: Text(tagLabels[i],
                      style: TextStyle(
                        color: sel ? context.taxi : context.ink,
                        fontSize: 14, fontWeight: FontWeight.w600,
                      )),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CtaButton(
            label: 'Готово',
            dark: true,
            enabled: _stars > 0,
            onTap: () {
              state.setDestination('');
              state.setClientState(ClientState.home);
            },
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Общие виджеты
// ════════════════════════════════════════════════════════════════

class _TripMini extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            _TripRow(isDot: true, label: state.fromAddress),
            Divider(height: 1, indent: 40, color: context.lineC),
            _TripRow(isDot: false,
                label: state.destination.isEmpty
                    ? 'Скажу водителю'
                    : state.destination,
                sub: state.tariffPrice),
          ],
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final bool isDot;
  final String label;
  final String? sub;
  const _TripRow({required this.isDot, required this.label, this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          isDot
              ? Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: context.ink, borderRadius: BorderRadius.circular(5)))
              : Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: context.taxi, borderRadius: BorderRadius.circular(3),
                    boxShadow: [BoxShadow(color: context.taxi.withOpacity(.3), blurRadius: 6)],
                  )),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerLeft,
              child: Text(label,
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 15, fontWeight: FontWeight.w600,
                  )),
            ),
          ),
          if (sub != null)
            Text(sub!,
                style: TextStyle(
                  color: context.muted, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Аватар
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: context.taxiSft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(mockDriver.initial,
                    style: TextStyle(
                      color: context.taxi,
                      fontSize: 19, fontWeight: FontWeight.w800,
                    )),
              ),
              Positioned(
                bottom: -7, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.paper,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(.1),
                            blurRadius: 6),
                      ],
                    ),
                    child: Text('★ ${mockDriver.rating}',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 11, fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mockDriver.name,
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 16, fontWeight: FontWeight.w700,
                    )),
                Text(
                    '${mockDriver.trips} поездок · ${mockDriver.car}',
                    style: TextStyle(color: context.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onCancel;
  const _ActionRow({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _IconAction(icon: Icons.phone_rounded, label: 'Позвонить'),
          _IconAction(icon: Icons.chat_bubble_outline_rounded, label: 'Написать'),
          _IconAction(icon: Icons.share_rounded, label: 'Поделиться'),
          _IconAction(icon: Icons.close_rounded, label: 'Отменить',
              isRed: true, onTap: onCancel),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isRed;
  final VoidCallback? onTap;
  const _IconAction({
    required this.icon, required this.label,
    this.isRed = false, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRed ? context.danger : context.ink2;
    final bg    = isRed ? context.dSoft  : context.surface;
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Column(
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  final String plate;
  const _Plate({required this.plate});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF14171F), width: 2),
        borderRadius: BorderRadius.circular(7),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            color: const Color(0xFF00A3C4),
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🇰🇿', style: TextStyle(fontSize: 9)),
                Text('KZ', style: TextStyle(
                  color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(plate,
                style: const TextStyle(
                  color: Color(0xFF14171F),
                  fontSize: 15, fontWeight: FontWeight.w800,
                  letterSpacing: .04 * 15,
                )),
          ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final String? sub;
  final bool soft, dark, enabled;
  final VoidCallback? onTap;
  const _CtaButton({
    required this.label,
    this.sub, this.soft = false, this.dark = false,
    this.enabled = true, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = soft ? context.surface
        : dark ? context.ink
        : context.taxi;
    final fg = soft ? context.ink
        : dark ? context.paper
        : context.onTaxi;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: soft || dark || !enabled ? null : [
              BoxShadow(
                color: context.taxi.withOpacity(.45),
                blurRadius: 26, offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                    color: fg, fontSize: 17, fontWeight: FontWeight.w700,
                    letterSpacing: -.01 * 17,
                  )),
              if (sub != null) ...[
                const SizedBox(width: 8),
                Text(sub!,
                    style: TextStyle(
                      color: fg.withOpacity(.8),
                      fontSize: 14, fontWeight: FontWeight.w600,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OptButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;
  const _OptButton({
    required this.icon, required this.label, required this.onTap, this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? context.ink, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 14, fontWeight: FontWeight.w600,
                    )),
              ),
              Icon(Icons.chevron_right_rounded, color: context.muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickChip({
    required this.label, required this.color,
    required this.icon, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.paper,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          padding: const EdgeInsets.only(left: 6, right: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.lineC),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(.15), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 14, fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// Тарифная карточка
class _TariffCard extends StatelessWidget {
  final Tariff tariff;
  final bool selected;
  final VoidCallback onTap;
  const _TariffCard({required this.tariff, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = _tariffData[tariff]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 122,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: selected ? context.paper : context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? context.taxi : Colors.transparent,
          width: 2,
        ),
        boxShadow: selected ? [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 10, offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: context.taxi.withOpacity(.08),
          highlightColor: context.taxi.withOpacity(.04),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CarSvg(tariff: tariff),
                    const SizedBox(height: 4),
                    Text(data.$1,
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 15, fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 1),
                    Text(data.$2,
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 16, fontWeight: FontWeight.w800,
                        )),
                    Text(data.$3,
                        style: TextStyle(
                          color: context.muted, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: 9, right: 9,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: context.taxi,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded,
                        color: context.onTaxi, size: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const _tariffData = {
  Tariff.local:    ('Посёлок',    '500 ₸',    '≈ 3 мин'),
  Tariff.border:   ('Ушарал',     '5 000 ₸',  'за место'),
  Tariff.whole:    ('Вся машина', '18 000 ₸', 'до Ушарала'),
  Tariff.delivery: ('Доставка',   '400 ₸',    'по посёлку'),
};


// ════════════════════════════════════════════════════════════════
//  Боковое меню
// ════════════════════════════════════════════════════════════════
class _SideDrawer extends StatelessWidget {
  final VoidCallback onClose;
  const _SideDrawer({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Drawer(
      child: Column(
        children: [
          // ── Шапка: тёмный фон, аватар, имя, телефон
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 26, 20, 20),
            color: const Color(0xFF14171F),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0x29127FDCC4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline_rounded,
                      color: Color(0xFF7FDCC4), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Гульнар',
                          style: TextStyle(
                            color: Color(0xFFF2F4F7),
                            fontSize: 17, fontWeight: FontWeight.w700,
                          )),
                      const Text('+7 7•• ••• •• 21',
                          style: TextStyle(
                            color: Color(0xFFA3ABB6), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Пункты меню
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _DrawerItem(
                  icon: Icons.access_time_outlined,
                  label: 'Мои поездки',
                  onTap: onClose,
                ),
                _DrawerItem(
                  icon: Icons.domain_outlined,
                  label: 'Межгород · Ушарал',
                  onTap: onClose,
                ),
                _DrawerItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Доставка',
                  onTap: onClose,
                ),
                _DrawerItem(
                  icon: Icons.drive_eta_outlined,
                  label: 'Режим водителя',
                  badge: 'демо',
                  onTap: () {
                    state.setDriverMode(!state.isDriverMode);
                    onClose();
                  },
                ),
                _DrawerItem(
                  icon: Icons.headset_outlined,
                  label: 'Поддержка',
                  onTap: onClose,
                ),
              ],
            ),
          ),

          // ── Блок темы + демо-примечание
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16,
                MediaQuery.of(context).padding.bottom + 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Коробка темы
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ТЕМА ОФОРМЛЕНИЯ',
                          style: TextStyle(
                            color: context.taxi,
                            fontSize: 12, fontWeight: FontWeight.w700,
                            letterSpacing: .08 * 12,
                          )),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: context.paper,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.lineC),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _ThemeBtn(
                                icon: Icons.brightness_auto_outlined,
                                label: 'Авто',
                                selected: state.themeMode == ThemeMode.system,
                                onTap: () => state.setTheme(ThemeMode.system)),
                            _ThemeBtn(
                                icon: Icons.wb_sunny_outlined,
                                label: 'Светлая',
                                selected: state.themeMode == ThemeMode.light,
                                onTap: () => state.setTheme(ThemeMode.light)),
                            _ThemeBtn(
                                icon: Icons.nights_stay_outlined,
                                label: 'Тёмная',
                                selected: state.themeMode == ThemeMode.dark,
                                onTap: () => state.setTheme(ThemeMode.dark)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Авто: как на телефоне — днём светлая, ночью тёмная',
                          style: TextStyle(
                            color: context.muted,
                            fontSize: 12.5, height: 1.4,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Демо-примечание
                Text('Демо-прототип. Имена, номера машин и цены — примеры.',
                    style: TextStyle(
                      color: context.taxi,
                      fontSize: 12, height: 1.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.ink, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 16, fontWeight: FontWeight.w600,
                    )),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.taxiSft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge!,
                      style: TextStyle(
                        color: context.taxi,
                        fontSize: 11.5, fontWeight: FontWeight.w700,
                      )),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 58,
            decoration: BoxDecoration(
              color: selected ? context.taxi : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? context.onTaxi : context.muted),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                      color: selected ? context.onTaxi : context.muted,
                      fontSize: 13, fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _MapFab({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: context.paper,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.15),
              blurRadius: 14, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color ?? context.ink, size: 22),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Модальные шторки
// ════════════════════════════════════════════════════════════════
class _PaymentSheet extends StatelessWidget {
  final AppState state;
  const _PaymentSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: context.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 5,
              decoration: BoxDecoration(
                color: context.line2C,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Способ оплаты',
              style: TextStyle(
                color: context.ink,
                fontSize: 20, fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 16),
          _PayOption(
            icon: '💵', label: 'Наличные',
            selected: state.paymentMethod == 'cash',
            onTap: () { state.setPayment('cash'); Navigator.pop(context); },
          ),
          const SizedBox(height: 8),
          _PayOption(
            icon: '💳', label: 'Kaspi',
            selected: state.paymentMethod == 'kaspi',
            onTap: () { state.setPayment('kaspi'); Navigator.pop(context); },
          ),
        ],
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  final String icon, label;
  final bool selected;
  final VoidCallback onTap;
  const _PayOption({required this.icon, required this.label,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.taxiSft : context.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? context.jLine : Colors.transparent),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 16, fontWeight: FontWeight.w600,
                    )),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: context.taxi),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishSheet extends StatelessWidget {
  const _WishSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: context.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 5,
                decoration: BoxDecoration(
                  color: context.line2C,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Пожелания водителю',
                style: TextStyle(
                  color: context.ink,
                  fontSize: 20, fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 12),
            TextField(
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Например: привезти сдачу, помочь с вещами…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.lineC),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.taxi, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _CtaButton(
              label: 'Сохранить',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Быстрые чипы данные ────────────────────────────────────────────────────
const _quickPlacesData = [
  ('Дом',           Color(0xFF0E7C66), Icons.home_outlined),
  ('Вокзал Достык', Color(0xFF6E56CF), Icons.train_outlined),
  ('Больница',      Color(0xFFE5484D), Icons.add_circle_outline),
  ('Таможня · КПП', Color(0xFF0B7A75), Icons.security),
  ('Школа',         Color(0xFFD97A00), Icons.school_outlined),
  ('Базар',         Color(0xFF13A35A), Icons.shopping_bag_outlined),
];
