import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../data/places.dart';
import '../state.dart';
import '../theme.dart';
import 'package:flutter_map/flutter_map.dart' show MapController, CameraFit;
import 'package:latlong2/latlong.dart' show Distance, LatLng;
import '../widgets/ornament_icon.dart';
import '../widgets/taxi_map.dart';
import '../widgets/car_svgs.dart';
import '../data/drivers.dart';
import 'driver_apply_screen.dart';
import 'search_screen.dart';
import 'trip_screen.dart';

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
  final _map = MapController();
  String? _fittedOrderId;
  LatLng? _fittedCar;
  int _fittedRoute = 0;
  int _movedPickup = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      state.resolvePickupAddress();
      final p = await state.locateMe();
      if (!mounted || p == null) return;
      // Клиент в одном из районов — переключаемся на него и ставим подачу к нему.
      // Далеко от всех районов — оставляем центр текущего.
      state.detectRegion(p);
      if (state.region.contains(p)) _map.move(p, 16);
    });
  }

  void _afterFrame(VoidCallback f) =>
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) f(); });

  EdgeInsets _fitPadding(AppState state) => EdgeInsets.fromLTRB(
      60, MediaQuery.of(context).padding.top + 110, 60,
      _bottomSheetHeight(state) + 40);

  void _fitRoute(AppState state) {
    final r = state.route;
    if (r == null || state.routeVersion == _fittedRoute) return;
    _fittedRoute = state.routeVersion;
    _afterFrame(() => _map.fitCamera(CameraFit.coordinates(
          coordinates: [...r.points, state.pickup, if (state.destPoint != null) state.destPoint!],
          maxZoom: 17,
          padding: _fitPadding(state),
        )));
  }

  void _followPickup(AppState state) {
    if (state.pickupVersion == _movedPickup) return;
    _movedPickup = state.pickupVersion;
    if (state.destPoint != null) return;
    _afterFrame(() => _map.move(state.pickup, _map.camera.zoom < 15 ? 16 : _map.camera.zoom));
  }

  void _chooseRegion(BuildContext context) {
    final state = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(0, 16, 0, MediaQuery.of(ctx).padding.bottom + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Где вы?',
                  style: TextStyle(
                    color: ctx.ink, fontSize: 20, fontWeight: FontWeight.w800,
                  )),
            ),
            for (final r in state.regions)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(Icons.location_city_rounded, color: ctx.taxi),
                title: Text(r.name,
                    style: TextStyle(
                      color: ctx.ink, fontSize: 17, fontWeight: FontWeight.w600,
                    )),
                trailing: r.id == state.regionId
                    ? Icon(Icons.check_rounded, color: ctx.taxi)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  state.setRegion(r.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _goToMe(AppState state) async {
    final p = await state.locateMe();
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Не удалось определить местоположение. '
            'Разрешите доступ к геолокации в настройках браузера.'),
      ));
      return;
    }
    _map.move(p, 16);
  }

  void _zoom(double delta) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(4, 18));
  }

  void _fitCarAndPickup(AppState state) {
    final car = state.driverLocation;
    final id = state.activeOrderId;
    if (car == null || id == null) return;
    final last = _fittedCar;
    if (_fittedOrderId == id && last != null && Distance()(last, car) < 2000) return;
    _fittedOrderId = id;
    _fittedCar = car;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _map.fitCamera(CameraFit.coordinates(
        coordinates: [car, state.pickup],
        maxZoom: 17,
        padding: EdgeInsets.fromLTRB(
            60, MediaQuery.of(context).padding.top + 90, 60,
            _bottomSheetHeight(state) + 50),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isHome = state.clientState == ClientState.home;
    final picking = isHome && state.pickMode != null;
    // Булавка подачи в центре, пока не выбрано назначение; потом — метка на месте.
    final pickupInCenter = isHome && state.destPoint == null && !picking;
    final showCar = state.clientState == ClientState.coming ||
        state.clientState == ClientState.arrived ||
        state.clientState == ClientState.ride;

    String? pinLabel;
    switch (state.clientState) {
      case ClientState.home:
        final eta = state.pickupEtaMinutes;
        pinLabel = picking ? null : eta == null ? 'Нет машин рядом' : '~$eta мин';
      case ClientState.seek:
        pinLabel = 'Ищем машину';
      case ClientState.coming:
        final d = state.driverDistanceMeters;
        final eta = state.etaMinutes;
        pinLabel = d != null && d < 100
            ? 'Прибывает'
            : eta != null ? '~$eta мин' : 'Водитель едет';
      case ClientState.arrived:
        pinLabel = 'Машина на месте';
      case ClientState.ride:
      case ClientState.rate:
        pinLabel = null;
    }
    if (showCar) _fitCarAndPickup(state);
    if (isHome && !picking) {
      _fitRoute(state);
      _followPickup(state);
    }
    // Только вошли в «Указать на карте» — сразу показываем адрес точки под булавкой.
    if (picking && state.pickPoint == null) {
      _afterFrame(() => state.updatePick(_map.camera.center));
    }

    final arrival = state.arrivalTime;
    final showDest = state.destPoint != null && !picking &&
        state.clientState != ClientState.rate;

    String? caption;
    if (pickupInCenter) {
      caption = state.pickupResolving
          ? 'Определяем адрес…'
          : state.pickupNear == null || state.fromAddress.contains(state.pickupNear!)
              ? state.fromAddress
              : '${state.fromAddress} · ${state.pickupNear}';
    } else if (picking) {
      caption = state.pickAddress ?? (state.pickPoint == null ? null : 'Определяем адрес…');
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _SideDrawer(onClose: () => Navigator.of(context).pop()),
      body: Stack(
        children: [
          // Карта на весь экран
          TaxiMap(
            controller: _map,
            initialCenter: state.region.center,
            centerPin: pickupInCenter || picking,
            pinLabel: pinLabel,
            pinCaption: caption,
            onCenterChanged: pickupInCenter
                ? state.setPickup
                : picking ? state.updatePick : null,
            pickup: state.clientState == ClientState.rate || pickupInCenter || picking
                ? null
                : state.pickup,
            dest: showDest ? state.destPoint : null,
            destLabel: arrival == null ? null : 'Приедете в ${_hm(arrival)}',
            route: showDest ? state.route?.points : null,
            car: showCar ? state.driverLocation : null,
            idleCars: isHome ? state.onlineDrivers : const [],
            me: state.myLocation,
            places: isHome ? state.places : const [],
            onPlaceTap: isHome && !picking ? state.selectPlace : null,
          ),

          // FAB — Меню
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 14,
            child: _MapFab(
              icon: Icons.menu_rounded,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),

          // Бренд-чип по центру; нажатие — выбор района
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: isHome && state.regions.length > 1
                    ? () => _chooseRegion(context)
                    : null,
                child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
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
                      state.regions.length > 1
                          ? state.region.name
                          : 'DOSTYQ TAXI',
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.01 * 14,
                      ),
                    ),
                    if (isHome && state.regions.length > 1)
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: context.muted, size: 20),
                  ],
                ),
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
                      onPressed: () => _zoom(1),
                    ),
                  ),
                  Divider(height: 1, color: context.lineC),
                  SizedBox(
                    width: 48, height: 46,
                    child: IconButton(
                      icon: Icon(Icons.remove, color: context.ink),
                      onPressed: () => _zoom(-1),
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
                  onTap: () => _goToMe(state),
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
    if (state.clientState == ClientState.home) {
      if (state.pickMode != null) return 210;
      if (state.selectedPlace != null) return 190;
    }
    if (!state.sheetExpanded) {
      return state.clientState == ClientState.home ? 155.0 : 56.0;
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
          bottom: state.sheetExpanded ||
                  (state.clientState == ClientState.home &&
                      (state.pickMode != null || state.selectedPlace != null))
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
            // Панель
            if (state.clientState == ClientState.home && state.pickMode != null)
              const _PickPanel()
            else if (state.clientState == ClientState.home && state.selectedPlace != null)
              _PlacePanel(place: state.selectedPlace!)
            else if (!state.sheetExpanded && state.clientState == ClientState.home)
              const _CollapsedHomePanel()
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
    final chips = _chipsOf(state.places);

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
                  state.pickupResolving ? 'Определяем адрес…' : state.fromAddress,
                  style: TextStyle(
                    color: context.ink2,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => openSearch(context, forFrom: true),
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
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _WhereField(),
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
            itemCount: chips.length,
            itemBuilder: (_, i) {
              final (label, color, icon, places) = chips[i];
              return _QuickChip(
                label: label, color: color, icon: icon,
                onTap: () => places.length == 1
                    ? state.setDestination(places.first.name, places.first.point)
                    : _choosePlace(context, label, places),
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
              onTap: () => state.setTariff(t),
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

        // Главная кнопка
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _buildCtaButton(context, state),
        ),
      ],
    );
  }

  Widget _buildCtaButton(BuildContext context, AppState state) {
    // Рейсы Ушарал
    if (state.tariff == Tariff.border) {
      return _CtaButton(
        label: 'Выбрать рейс',
        sub: '${formatPrice(state.settings.seatPrice)} / место',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TripScreen()),
        ),
      );
    }
    // Вся машина
    if (state.tariff == Tariff.whole) {
      return _CtaButton(
        label: 'Выбрать время',
        sub: formatPrice(state.settings.wholeCarPrice),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const TripScreen(wholeCarMode: true)),
        ),
      );
    }
    // Доставка
    if (state.tariff == Tariff.delivery) {
      return _CtaButton(
        label: 'Оформить доставку',
        sub: formatPrice(state.settings.deliveryPrice),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оформление доставки появится на этапе 6'),
            duration: Duration(seconds: 2),
          ),
        ),
      );
    }
    // Обычный заказ (local)
    return _CtaButton(
      label: state.destination.isEmpty ? 'Куда едем?' : 'Заказать',
      sub: state.destination.isEmpty ? null : state.tariffPrice,
      onTap: () {
        if (state.destination.isEmpty) {
          openSearch(context);
        } else {
          final messenger = ScaffoldMessenger.of(context);
          state.placeOrder().catchError((Object e) {
            messenger.showSnackBar(SnackBar(
              content: Text('Не удалось отправить заказ: $e'),
              duration: const Duration(seconds: 6),
            ));
          });
        }
      },
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
//  Свёрнутая панель «Главная» — поле куда + цена тарифа
// ════════════════════════════════════════════════════════════════
class _CollapsedHomePanel extends StatelessWidget {
  const _CollapsedHomePanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Поле «Куда едем?»
          const _WhereField(),
          const SizedBox(height: 8),
          // Строка: тариф + цена слева, стрелка «развернуть» справа
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: context.taxiSft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.tariffName} · ${state.tariffPrice}',
                  style: TextStyle(
                    color: context.taxi,
                    fontSize: 14, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => state.toggleSheet(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text('Подробнее',
                          style: TextStyle(
                            color: context.muted,
                            fontSize: 13, fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_up_rounded,
                          color: context.muted, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
    // Раз в 10 с перепроверяем, не пора ли сказать «машин нет, заказ у менеджера».
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }
  @override
  void dispose() { _ctrl.dispose(); _tick?.cancel(); super.dispose(); }
  Timer? _tick;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final declined = state.activeOrder?.declinedBy.isNotEmpty ?? false;
    final since = state.stateEnteredAt;
    final noCars = since != null &&
        DateTime.now().difference(since).inMinutes >= state.settings.showAllMinutes;
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
                    Text(noCars
                            ? 'Свободных машин пока нет. Заказ передан менеджеру — он подберёт машину'
                            : declined
                                ? 'Водитель отказался. Ищем другого'
                                : 'Предлагаем заказ ближайшему водителю',
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
            onTap: () => state.cancelOrder(),
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
    final state = context.watch<AppState>();
    final eta = state.etaMinutes;
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
                    Text(eta == null ? 'Водитель едет к вам' : 'Приедет через $eta мин',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 24, fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 4),
                    Text(context.watch<AppState>().activeOrder?.driverCar ?? '',
                        style: TextStyle(color: context.muted, fontSize: 14)),
                  ],
                ),
              ),
              _Plate(plate: context.watch<AppState>().activeOrder?.driverPlate ?? '—'),
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
        _ActionRow(onCancel: () => state.cancelOrder()),
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
    final state = context.watch<AppState>();
    final comingOut = state.activeOrder?.clientComingOut ?? false;
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
                    Text(context.watch<AppState>().activeOrder?.driverCar ?? '',
                        style: TextStyle(color: context.muted, fontSize: 14)),
                  ],
                ),
              ),
              _Plate(plate: context.watch<AppState>().activeOrder?.driverPlate ?? '—'),
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
            label: comingOut ? 'Водитель знает, что вы выходите' : 'Выхожу',
            soft: comingOut,
            onTap: () => state.markComingOut(),
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
      setState(() => _progress = (_progress + .08).clamp(0, .95));
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
                    Text('В пути',
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
              _Plate(plate: context.watch<AppState>().activeOrder?.driverPlate ?? '—'),
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
          child: Text(_initial(state.activeOrder?.driverName),
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
            onTap: () => state.finishRating(_stars),
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

String _initial(String? name) =>
    (name == null || name.isEmpty) ? mockDriver.initial : name.characters.first.toUpperCase();

class _DriverRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final driverName = context.watch<AppState>().activeOrder?.driverName;
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
                child: Text(_initial(driverName),
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
                Text((driverName == null || driverName.isEmpty) ? mockDriver.name : driverName,
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 16, fontWeight: FontWeight.w700,
                    )),
                Text(
                    [context.watch<AppState>().activeOrder?.driverCar, context.watch<AppState>().activeOrder?.driverPlate]
                        .whereType<String>().where((s) => s.isNotEmpty).join(' · '),
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
    final state = context.watch<AppState>();
    final s = state.settings;
    var (name, price, note) = switch (tariff) {
      Tariff.local    => ('Посёлок', formatPrice(s.localPrice), '≈ 3 мин'),
      Tariff.border   => ('Ушарал', formatPrice(s.seatPrice), 'за место'),
      Tariff.whole    => ('Вся машина', formatPrice(s.wholeCarPrice), 'до Ушарала'),
      Tariff.delivery => ('Доставка', formatPrice(s.deliveryPrice), 'по посёлку'),
    };
    if (tariff == Tariff.local) {
      price = formatPrice(state.localPriceInt);
      if (state.isKppTrip) {
        note = 'Таможня · КПП';
      } else if (state.isFarTrip) {
        note = 'дальше 3 км';
      }
    }
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
                    Text(name,
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 15, fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 1),
                    Text(price,
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 16, fontWeight: FontWeight.w800,
                        )),
                    Text(note,
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
                      Text(state.userName.isEmpty ? 'Клиент' : state.userName,
                          style: const TextStyle(
                            color: Color(0xFFF2F4F7),
                            fontSize: 17, fontWeight: FontWeight.w700,
                          )),
                      Text(FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
                          style: const TextStyle(
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
                  label: state.myDriver?.approval == Approval.approved
                      ? 'Режим водителя'
                      : 'Стать водителем',
                  badge: switch (state.myDriver?.approval) {
                    Approval.pending => 'на проверке',
                    Approval.rejected => 'отклонена',
                    _ => null,
                  },
                  onTap: () {
                    onClose();
                    if (state.myDriver?.approval == Approval.approved) {
                      state.setDriverMode(true);
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const DriverApplyScreen(),
                      ));
                    }
                  },
                ),
                _DrawerItem(
                  icon: Icons.headset_outlined,
                  label: 'Поддержка',
                  onTap: onClose,
                ),
                _DrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Выйти',
                  onTap: () {
                    onClose();
                    FirebaseAuth.instance.signOut();
                  },
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

// ─── Быстрые чипы: одиночные места и группы (одна «Школа» на все школы) ──────
List<(String, Color, IconData, List<Place>)> _chipsOf(List<Place> places) {
  final out = <(String, Color, IconData, List<Place>)>[];
  final seen = <String>{};
  for (final p in places.where((p) => p.chip)) {
    final g = p.group;
    if (g == null) {
      out.add((p.name, p.color, p.icon, [p]));
    } else if (seen.add(g)) {
      out.add((placeGroups[g] ?? p.name, p.color, p.icon,
          places.where((x) => x.group == g).toList()));
    }
  }
  return out;
}

void _choosePlace(BuildContext context, String title, List<Place> places) {
  final state = context.read<AppState>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: ctx.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(0, 10, 0, MediaQuery.of(ctx).padding.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 5,
              decoration: BoxDecoration(
                color: ctx.line2C,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text('$title — какая?',
                style: TextStyle(
                  color: ctx.ink,
                  fontSize: 20, fontWeight: FontWeight.w800,
                )),
          ),
          for (final p in places)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: p.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(p.icon, color: p.color, size: 22),
              ),
              title: Text(p.name,
                  style: TextStyle(
                    color: ctx.ink, fontSize: 16, fontWeight: FontWeight.w600,
                  )),
              subtitle: Text(p.sub,
                  style: TextStyle(color: ctx.muted, fontSize: 13)),
              trailing: Text(
                formatDistance(Distance()(state.pickup, p.point)),
                style: TextStyle(
                  color: ctx.muted, fontSize: 13, fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                state.setDestination(p.name, p.point);
              },
            ),
        ],
      ),
    ),
  );
}

void openSearch(BuildContext context, {bool forFrom = false}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SearchScreen(forFrom: forFrom),
    fullscreenDialog: true,
  ));
}

// ─── Поле «Куда»: название места крупно, справа расстояние и время ──────────
class _WhereField extends StatelessWidget {
  const _WhereField();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final has = state.destination.isNotEmpty;
    final r = state.route;
    return GestureDetector(
      onTap: () => openSearch(context),
      child: Container(
        height: 58,
        padding: const EdgeInsets.only(left: 16, right: 6),
        decoration: BoxDecoration(
          color: has ? context.taxiSft : context.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: has ? context.jLine : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: context.taxi,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(color: context.taxi.withOpacity(.3), blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                has ? state.destination : 'Куда едем?',
                style: TextStyle(
                  color: has ? context.ink : context.hint,
                  fontSize: 19,
                  fontWeight: has ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: -.02 * 19,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (has) ...[
              const SizedBox(width: 8),
              Text(
                r == null
                    ? '…'
                    : '${formatDistance(r.meters)} · ${r.minutes} мин',
                style: TextStyle(
                  color: context.taxi,
                  fontSize: 13.5, fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.muted, size: 20),
                tooltip: 'Убрать',
                onPressed: state.clearDestination,
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.search_rounded, color: context.muted, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── «Указать на карте» ─────────────────────────────────────────────────────
class _PickPanel extends StatelessWidget {
  const _PickPanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final forFrom = state.pickMode == 'from';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: context.ink),
                onPressed: state.cancelPick,
                style: IconButton.styleFrom(backgroundColor: context.surface),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forFrom
                          ? 'Двигайте карту — машина приедет к булавке'
                          : 'Двигайте карту — куда поедем',
                      style: TextStyle(color: context.muted, fontSize: 12.5),
                    ),
                    Text(
                      state.pickAddress ?? 'Определяем адрес…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 20, fontWeight: FontWeight.w800,
                        letterSpacing: -.02 * 20,
                      ),
                    ),
                    if (state.pickNear != null)
                      Text('Рядом: ${state.pickNear}',
                          style: TextStyle(
                            color: context.taxi,
                            fontSize: 13, fontWeight: FontWeight.w600,
                          )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CtaButton(
            label: 'Готово',
            enabled: state.pickPoint != null,
            onTap: state.confirmPick,
          ),
        ],
      ),
    );
  }
}

// ─── Карточка места, нажатого на карте ──────────────────────────────────────
class _PlacePanel extends StatelessWidget {
  final Place place;
  const _PlacePanel({required this.place});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: place.color.withOpacity(.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(place.icon, color: place.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name,
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 20, fontWeight: FontWeight.w800,
                        )),
                    Text(place.sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.muted, fontSize: 13.5)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.ink),
                onPressed: () => state.selectPlace(null),
                style: IconButton.styleFrom(backgroundColor: context.surface),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CtaButton(
                  label: 'Отсюда',
                  soft: true,
                  onTap: () {
                    state.selectPlace(null);
                    state.setPickupPlace(place.name, place.point);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CtaButton(
                  label: 'Сюда',
                  onTap: () => state.setDestination(place.name, place.point),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
