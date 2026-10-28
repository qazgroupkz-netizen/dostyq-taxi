import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'data/orders.dart';

enum ClientState { home, seek, coming, arrived, ride, rate }
enum DriverState { offline, waiting, offer, active }
enum Tariff { local, border, whole, delivery }

class AppState extends ChangeNotifier {
  AppState({OrderRepository? orders})
      : orders = orders ?? FirestoreOrderRepository() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) async {
      uid = u?.uid;
      userName = u == null ? '' : await this.orders.userName(u.uid);
      notifyListeners();
    });
  }

  final OrderRepository orders;
  StreamSubscription<User?>? _authSub;
  String? uid;
  String userName = '';

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

  // ─── Заказ клиента ──────────────────────────────────────────────────────
  String? activeOrderId;
  TaxiOrder? activeOrder;
  StreamSubscription<TaxiOrder?>? _clientOrderSub;

  Future<void> placeOrder() async {
    if (uid == null) return;
    setClientState(ClientState.seek);
    final id = await orders.create(
      clientId: uid!,
      clientName: await _myName(),
      from: fromAddress,
      to: destination,
      tariff: tariff.name,
      price: tariffPriceInt,
      payment: paymentMethod,
    );
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
    if (next == ClientState.home || next == ClientState.rate) {
      _clientOrderSub?.cancel();
      _clientOrderSub = null;
    }
    if (next == ClientState.home) {
      activeOrderId = null;
      activeOrder = null;
    }
    if (next != clientState) {
      setClientState(next);
    } else {
      notifyListeners();
    }
  }

  Future<void> cancelOrder() async {
    final id = activeOrderId;
    _clientOrderSub?.cancel();
    _clientOrderSub = null;
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
      if (!_skipped.contains(o.id)) return o;
    }
    return null;
  }

  DriverState get driverState => driverOrder != null
      ? DriverState.active
      : offer != null
          ? DriverState.offer
          : DriverState.waiting;

  void _syncDriverListening() {
    final listen = isDriverMode && isOnline;
    if (listen && _searchSub == null) {
      _searchSub = orders.watchSearching().listen((list) {
        _searching = list;
        notifyListeners();
      });
    } else if (!listen && _searchSub != null) {
      _searchSub!.cancel();
      _searchSub = null;
      _searching = [];
    }
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
      if (d == null || d.status == 'cancelled' || d.status == 'done') {
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
    if (o != null) await orders.setStatus(o.id, 'cancelled');
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _clientOrderSub?.cancel();
    _searchSub?.cancel();
    _driverOrderSub?.cancel();
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
