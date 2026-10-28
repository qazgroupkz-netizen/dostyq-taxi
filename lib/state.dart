import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'data/orders.dart';
import 'services/location.dart';
import 'services/sound.dart';
import 'widgets/taxi_map.dart' show dostykCenter;

enum ClientState { home, seek, coming, arrived, ride, rate }
enum DriverState { offline, waiting, offer, active }
enum Tariff { local, border, whole, delivery }

class AppState extends ChangeNotifier {
  AppState({OrderRepository? orders})
      : orders = orders ?? FirestoreOrderRepository() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      uid = u?.uid;
      userName = '';
      profileLoaded = false;
      notifyListeners();
      if (u != null) reloadProfile();
    });
  }

  final OrderRepository orders;
  StreamSubscription<User?>? _authSub;
  String? uid;
  String userName = '';
  bool profileLoaded = false;

  Future<void> reloadProfile() async {
    final id = uid;
    if (id == null) return;
    try {
      userName = await orders.userName(id);
    } catch (_) {
      userName = '';
    }
    if (id != uid) return;
    profileLoaded = true;
    notifyListeners();
  }

  Future<String> _myName() async {
    if (userName.isEmpty && uid != null) userName = await orders.userName(uid!);
    return userName;
  }

  // ─── Режим ──────────────────────────────────────────────────────────────
  bool isDriverMode = false;
  ThemeMode themeMode = ThemeMode.system;

  // ─── Клиент ─────────────────────────────────────────────────────────────
  ClientState clientState = ClientState.home;
  Tariff tariff = Tariff.local;
  String destination = '';
  String fromAddress = 'ул. Молдагуловой';
  String paymentMethod = 'cash'; // cash | kaspi

  // ─── UI ─────────────────────────────────────────────────────────────────
  bool sheetExpanded = true;

  // ─── Водитель ────────────────────────────────────────────────────────────
  bool isOnline = true;

  // ─── Сеттеры ────────────────────────────────────────────────────────────
  void setDriverMode(bool v) {
    isDriverMode = v;
    _syncDriverListening();
    notifyListeners();
  }
  void setTheme(ThemeMode m)  { themeMode = m;   notifyListeners(); }

  // Когда вошли в текущее состояние — для вычисления ETA на карте
  DateTime? stateEnteredAt;

  void setClientState(ClientState s) {
    clientState = s;
    stateEnteredAt = DateTime.now();
    notifyListeners();
  }
  void setTariff(Tariff t)           { tariff = t;       notifyListeners(); }
  void setDestination(String d)      { destination = d;  notifyListeners(); }
  void setPayment(String p)          { paymentMethod = p; notifyListeners(); }

  void toggleOnline() {
    isOnline = !isOnline;
    _syncDriverListening();
    notifyListeners();
  }
  void toggleSheet()  { sheetExpanded = !sheetExpanded; notifyListeners(); }

  // ─── Местоположение ─────────────────────────────────────────────────────
  LatLng pickup = dostykCenter;
  LatLng? myLocation;
  LatLng? driverLocation;
  StreamSubscription<Geo?>? _driverLocSub;

  void setPickup(LatLng p) {
    if (clientState != ClientState.home) return;
    if (Distance()(p, pickup) < 3) return;
    pickup = p;
    fromAddress = 'Точка на карте';
    notifyListeners();
  }

  Future<LatLng?> locateMe() async {
    final p = await LocationService.current();
    if (p != null) {
      myLocation = p;
      notifyListeners();
    }
    return p;
  }

  /// Минуты до подачи по прямой, при средней скорости 25 км/ч.
  int? get etaMinutes {
    final car = driverLocation;
    if (car == null) return null;
    final m = Distance()(car, pickup);
    return (m / 420).ceil().clamp(1, 999);
  }

  double? get driverDistanceMeters {
    final car = driverLocation;
    return car == null ? null : Distance()(car, pickup);
  }

  void _watchDriverOf(TaxiOrder o) {
    final id = o.driverId;
    if (id == null || _driverLocSub != null) return;
    _driverLocSub = orders.watchDriverLocation(id).listen((g) {
      driverLocation = g == null ? null : LatLng(g.lat, g.lng);
      notifyListeners();
    });
  }

  void _stopWatchingDriver() {
    _driverLocSub?.cancel();
    _driverLocSub = null;
    driverLocation = null;
  }

  // ─── Заказ клиента ──────────────────────────────────────────────────────
  String? activeOrderId;
  TaxiOrder? activeOrder;
  StreamSubscription<TaxiOrder?>? _clientOrderSub;

  Future<void> placeOrder() async {
    if (uid == null) return;
    setClientState(ClientState.seek);
    final String id;
    try {
      id = await orders.create(
        clientId: uid!,
        clientName: await _myName(),
        from: fromAddress,
        fromGeo: (lat: pickup.latitude, lng: pickup.longitude),
        to: destination,
        tariff: tariff.name,
        price: tariffPriceInt,
        payment: paymentMethod,
      );
    } catch (_) {
      setClientState(ClientState.home);
      rethrow;
    }
    if (clientState != ClientState.seek) {
      await orders.setStatus(id, 'cancelled');
      return;
    }
    activeOrderId = id;
    _clientOrderSub?.cancel();
    _clientOrderSub = orders.watch(id).listen(_onClientOrder);
  }

  void _onClientOrder(TaxiOrder? o) {
    if (o == null) return;
    activeOrder = o;
    final next = switch (o.status) {
      'accepted'  => ClientState.coming,
      'arrived'   => ClientState.arrived,
      'riding'    => ClientState.ride,
      'done'      => ClientState.rate,
      'cancelled' => ClientState.home,
      _           => ClientState.seek,
    };
    if (next == ClientState.coming ||
        next == ClientState.arrived ||
        next == ClientState.ride) {
      _watchDriverOf(o);
    }
    if (next == ClientState.home || next == ClientState.rate) {
      _clientOrderSub?.cancel();
      _clientOrderSub = null;
      _stopWatchingDriver();
    }
    // Водитель отказался — заказ снова в поиске, следим уже за следующим водителем.
    if (next == ClientState.seek && clientState != ClientState.seek) {
      _stopWatchingDriver();
      playAlert();
    }
    if (next == ClientState.home) {
      activeOrderId = null;
      activeOrder = null;
    }
    if (next != clientState) {
      if (next == ClientState.coming || next == ClientState.arrived) playAlert();
      setClientState(next);
    } else {
      notifyListeners();
    }
  }

  Future<void> cancelOrder() async {
    final id = activeOrderId;
    _clientOrderSub?.cancel();
    _clientOrderSub = null;
    _stopWatchingDriver();
    activeOrderId = null;
    activeOrder = null;
    setClientState(ClientState.home);
    if (id != null) await orders.setStatus(id, 'cancelled');
  }

  Future<void> markComingOut() async {
    final id = activeOrderId;
    if (id != null) await orders.update(id, {'clientComingOut': true});
  }

  Future<void> finishRating(int stars) async {
    final id = activeOrderId;
    activeOrderId = null;
    activeOrder = null;
    destination = '';
    setClientState(ClientState.home);
    if (id != null) await orders.update(id, {'rating': stars});
  }

  // ─── Заказы водителя ────────────────────────────────────────────────────
  // Пока без сервера назначения: свободный водитель видит все новые заказы.
  List<TaxiOrder> _searching = [];
  final Set<String> _skipped = {};
  TaxiOrder? driverOrder;
  StreamSubscription<List<TaxiOrder>>? _searchSub;
  StreamSubscription<TaxiOrder?>? _driverOrderSub;

  TaxiOrder? get offer {
    if (!isOnline || driverOrder != null) return null;
    for (final o in _searching) {
      if (!_skipped.contains(o.id) && !o.declinedBy.contains(uid)) return o;
    }
    return null;
  }

  DriverState get driverState => driverOrder != null
      ? DriverState.active
      : offer != null
          ? DriverState.offer
          : DriverState.waiting;

  StreamSubscription<LatLng>? _gpsSub;
  DateTime _lastGpsSent = DateTime.fromMillisecondsSinceEpoch(0);

  void _syncDriverListening() {
    final listen = isDriverMode && isOnline;
    if (listen && _searchSub == null) {
      _searchSub = orders.watchSearching().listen((list) {
        _searching = list;
        notifyListeners();
      });
      _startGps();
      if (uid != null) orders.setDriverOnline(uid!, true);
    } else if (!listen && _searchSub != null) {
      _searchSub!.cancel();
      _searchSub = null;
      _searching = [];
      _gpsSub?.cancel();
      _gpsSub = null;
      if (uid != null) orders.setDriverOnline(uid!, false);
    }
  }

  void _startGps() {
    _gpsSub?.cancel();
    _gpsSub = LocationService.watch().listen(_onGps);
    // Первая точка сразу, не дожидаясь движения.
    LocationService.current().then((p) {
      if (p != null && _gpsSub != null) _onGps(p);
    });
  }

  // ─── Демо-поездка: водитель «едет» к клиенту без настоящего GPS ─────────
  Timer? _simTimer;
  bool get simulating => _simTimer != null;

  void startSimulation() {
    final o = driverOrder;
    if (o == null || o.fromLat == null || uid == null) return;
    final target = LatLng(o.fromLat!, o.fromLng!);
    final d = Distance();
    var pos = myLocation;
    // Водитель далеко от Достыка — начинаем в 1,5 км от клиента.
    if (pos == null || d(pos, target) > 3000) pos = d.offset(target, 1500, 45);
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      final left = d(pos!, target);
      pos = left <= 30 ? target : d.offset(pos!, 30, d.bearing(pos!, target));
      myLocation = pos;
      orders.updateDriverLocation(uid!, (lat: pos!.latitude, lng: pos!.longitude));
      if (left <= 30) stopSimulation();
      notifyListeners();
    });
    notifyListeners();
  }

  void stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    notifyListeners();
  }

  void _onGps(LatLng p) {
    if (simulating) return;
    myLocation = p;
    notifyListeners();
    final now = DateTime.now();
    if (uid == null || now.difference(_lastGpsSent).inSeconds < 4) return;
    _lastGpsSent = now;
    orders.updateDriverLocation(uid!, (lat: p.latitude, lng: p.longitude));
  }

  void skipOffer(String id) {
    _skipped.add(id);
    notifyListeners();
  }

  Future<void> acceptOffer(TaxiOrder o) async {
    if (uid == null) return;
    final ok = await orders.accept(o.id,
        driverId: uid!, driverName: await _myName());
    if (!ok) {
      skipOffer(o.id);
      return;
    }
    driverOrder = o;
    notifyListeners();
    _driverOrderSub?.cancel();
    _driverOrderSub = orders.watch(o.id).listen((d) {
      if (d == null ||
          d.status == 'cancelled' ||
          d.status == 'done' ||
          d.driverId != uid) {
        if (d?.status == 'cancelled') playAlert();
        _simTimer?.cancel();
        _simTimer = null;
        driverOrder = null;
        _driverOrderSub?.cancel();
        _driverOrderSub = null;
      } else {
        driverOrder = d;
      }
      notifyListeners();
    });
  }

  Future<void> advanceRide() async {
    final o = driverOrder;
    if (o == null) return;
    const next = {'accepted': 'arrived', 'arrived': 'riding', 'riding': 'done'};
    final s = next[o.status];
    if (s != null) await orders.setStatus(o.id, s);
  }

  Future<void> driverCancel() async {
    final o = driverOrder;
    if (o == null || uid == null) return;
    _skipped.add(o.id);
    await orders.release(o.id, uid!);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _clientOrderSub?.cancel();
    _searchSub?.cancel();
    _driverOrderSub?.cancel();
    _driverLocSub?.cancel();
    _gpsSub?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }

  // ─── Геттеры ─────────────────────────────────────────────────────────────
  String get tariffName {
    switch (tariff) {
      case Tariff.local:    return 'Посёлок';
      case Tariff.border:   return 'Ушарал';
      case Tariff.whole:    return 'Вся машина';
      case Tariff.delivery: return 'Доставка';
    }
  }

  String get tariffPrice {
    switch (tariff) {
      case Tariff.local:    return '500 ₸';
      case Tariff.border:   return '5 000 ₸';
      case Tariff.whole:    return '18 000 ₸';
      case Tariff.delivery: return '400 ₸';
    }
  }

  int get tariffPriceInt {
    switch (tariff) {
      case Tariff.local:    return 500;
      case Tariff.border:   return 5000;
      case Tariff.whole:    return 18000;
      case Tariff.delivery: return 400;
    }
  }

  String get paymentLabel =>
      paymentMethod == 'kaspi' ? 'Kaspi' : 'Наличные';
}

// ─── Мок-данные (для Stage 2 — без сервера) ─────────────────────────────────
class MockDriver {
  final String name;
  final String initial;
  final String car;
  final String plate;
  final String rating;
  final int trips;
  const MockDriver({
    required this.name, required this.initial,
    required this.car,  required this.plate,
    required this.rating, required this.trips,
  });
}

const mockDriver = MockDriver(
  name: 'Ерлан',   initial: 'Е',
  car:  'Белая Toyota Camry',
  plate: '045 AKZ 18',
  rating: '4,9',   trips: 1240,
);

const mockPlaces = [
  ('Больница',  'Ул. Молдагуловой, 14',  Icons.add_circle_outline,       Color(0xFFE5484D)),
  ('Рынок',     'Центральный рынок',     Icons.shopping_bag_outlined,    Color(0xFF13A35A)),
  ('Школа №1',  'Ул. Достык, 1',        Icons.school_outlined,          Color(0xFFD97A00)),
  ('Мечеть',    'Ул. Молдагуловой, 32', Icons.mosque,                   Color(0xFF6E56CF)),
  ('КПП',       'Граница',              Icons.security,                 Color(0xFF0B7A75)),
  ('Почта',     'Ул. Сейткали',         Icons.mail_outline,             Color(0xFF4A5160)),
  ('Аптека',    'Ул. Молдагуловой, 8',  Icons.local_pharmacy_outlined,  Color(0xFF13A35A)),
  ('Детсад',    'Ул. Достык, 5',        Icons.child_care,               Color(0xFFD97A00)),
];
