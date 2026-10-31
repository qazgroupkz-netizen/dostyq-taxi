import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'config.dart';
import 'data/auth.dart';
import 'data/catalog.dart';
import 'data/drivers.dart';
import 'data/orders.dart';
import 'data/places.dart';
import 'data/regions.dart';
import 'data/settings.dart';
import 'data/streets.dart';
import 'data/trips.dart';
import 'data/supabase/sb_catalog.dart';
import 'data/supabase/sb_drivers.dart';
import 'data/supabase/sb_orders.dart';
import 'data/supabase/sb_trips.dart';
import 'i18n.dart';
import 'services/geo_api.dart';
import 'services/location.dart';
import 'services/sound.dart';
import 'widgets/taxi_map.dart' show dostykCenter;

enum ClientState { home, seek, coming, arrived, ride, rate }
enum DriverState { offline, waiting, offer, active }
enum Tariff { local, border, whole, delivery, cargo }

class AppState extends ChangeNotifier {
  AppState({
    OrderRepository? orders,
    CatalogRepository? catalog,
    DriverRepository? drivers,
    TripRepository? trips,
  })  : orders = orders ?? (kUseSupabase ? SupabaseOrderRepository() : FirestoreOrderRepository()),
        catalog = catalog ?? (kUseSupabase ? SupabaseCatalogRepository() : FirestoreCatalogRepository()),
        drivers = drivers ?? (kUseSupabase ? SupabaseDriverRepository() : FirestoreDriverRepository()),
        trips = trips ?? (kUseSupabase ? SupabaseTripRepository() : FirestoreTripRepository()) {
    _authSub = authRepo.changes().listen((u) {
      authReady = true;
      uid = u?.uid;
      userName = '';
      role = 'client';
      profileLoaded = false;
      _placesSub?.cancel();
      _placesSub = null;
      _regionsSub?.cancel();
      _regionsSub = null;
      _myDriverSub?.cancel();
      _myDriverSub = null;
      myDriver = null;
      if (u != null) {
        _myDriverSub = this.drivers.watchProfile(u.uid).listen((p) {
          myDriver = p;
          _syncDriverListening();
          notifyListeners();
        }, onError: (_) {});
        _placesSub = this.catalog.watchPlaces().listen((list) {
          allPlacesFromDb = list;
          notifyListeners();
        }, onError: (_) {});
        _regionsSub = this.catalog.watchRegions().listen((list) {
          regionsFromDb = list;
          notifyListeners();
        }, onError: (_) {});
      }
      _subscribeRegion();
      notifyListeners();
      if (u != null) reloadProfile();
    });
  }

  // ─── Район ──────────────────────────────────────────────────────────────
  List<Region> regionsFromDb = const [];
  StreamSubscription<List<Region>>? _regionsSub;
  String regionId = defaultRegionId;

  /// Все районы (для админки), включая выключенные.
  List<Region> get allRegions => regionsFromDb.isEmpty ? builtInRegions : regionsFromDb;

  /// Районы, которые видит клиент.
  List<Region> get regions => allRegions.where((r) => r.active).toList();

  Region get region => allRegions.firstWhere(
        (r) => r.id == regionId,
        orElse: () => builtInRegions.first,
      );

  /// Цены, машины на линии и заказы для водителя — только своего района.
  void _subscribeRegion() {
    _onlineSub?.cancel();
    _onlineSub = null;
    _settingsSub?.cancel();
    _settingsSub = null;
    _streetsSub?.cancel();
    _streetsSub = null;
    streets = const [];
    onlineDrivers = [];
    settings = const TariffSettings();
    if (uid == null) return;
    _onlineSub = orders.watchOnlineDrivers(regionId).listen((list) {
      onlineDrivers = [for (final g in list) LatLng(g.lat, g.lng)];
      notifyListeners();
    }, onError: (_) {});
    _settingsSub = catalog.watchSettings(regionId).listen((s) {
      settings = s;
      notifyListeners();
    }, onError: (_) {});
    _streetsSub = catalog.watchStreets(regionId).listen((list) {
      streets = list;
      notifyListeners();
    }, onError: (_) {});
  }

  void setRegion(String id, {bool movePickup = true}) {
    if (id == regionId) return;
    regionId = id;
    _subscribeRegion();
    if (_searchSub != null) {
      _searchSub!.cancel();
      _searchSub = null;
      _syncDriverListening();
    }
    selectedPlace = null;
    pickMode = null;
    clearDestination();
    if (movePickup && clientState == ClientState.home) {
      pickup = region.center;
      pickupVersion++;
      resolvePickupAddress();
    }
    notifyListeners();
  }

  /// Клиент открыл приложение — ставим район по его местоположению.
  void detectRegion(LatLng p) {
    for (final r in regions) {
      if (r.contains(p)) {
        setRegion(r.id, movePickup: false);
        return;
      }
    }
  }

  final OrderRepository orders;
  final CatalogRepository catalog;
  final DriverRepository drivers;
  final TripRepository trips;

  /// Анкета водителя этого пользователя (пустая, если не подавал).
  DriverProfile? myDriver;
  StreamSubscription<DriverProfile>? _myDriverSub;

  bool get driverCanWork => myDriver?.canWork ?? false;
  StreamSubscription<AuthUser?>? _authSub;

  /// Уже известно, вошёл ли пользователь (до этого — экран загрузки).
  bool authReady = false;
  String? uid;
  String userName = '';
  String role = 'client';
  bool profileLoaded = false;

  bool get isAdmin => role == 'admin' || role == 'manager';

  // ─── Цены и места из админки ────────────────────────────────────────────
  TariffSettings settings = const TariffSettings();
  StreamSubscription<TariffSettings>? _settingsSub;

  /// Места всех районов из базы; пусто — админ ещё не загрузил, берём встроенный список.
  List<Place> allPlacesFromDb = const [];
  StreamSubscription<List<Place>>? _placesSub;

  /// Места текущего района из базы.
  List<Place> get placesFromDb =>
      allPlacesFromDb.where((p) => p.region == regionId).toList();

  /// Улицы текущего района (для поиска «абая 12»).
  List<Street> streets = const [];
  StreamSubscription<List<Street>>? _streetsSub;

  List<Place> get places {
    if (allPlacesFromDb.isNotEmpty) return placesFromDb;
    return regionId == defaultRegionId ? dostykPlaces : const [];
  }

  Future<void> reloadProfile() async {
    final id = uid;
    if (id == null) return;
    try {
      final p = await orders.userProfile(id);
      userName = p.name;
      role = p.role;
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
  String fromAddress = 'Определяем адрес…';
  String paymentMethod = 'cash'; // cash | kaspi

  /// Что везти / что купить — для грузового и доставки.
  String orderComment = '';

  /// Цена клиента для грузового (как в inDrive); null — пусть предложат водители.
  int? orderClientPrice;

  // ─── UI ─────────────────────────────────────────────────────────────────
  bool sheetExpanded = true;

  // ─── Водитель ────────────────────────────────────────────────────────────
  bool isOnline = true;

  // ─── Сеттеры ────────────────────────────────────────────────────────────
  void setDriverMode(bool v) {
    isDriverMode = v;
    // Водитель работает в районе из своей анкеты.
    final r = myDriver?.region;
    if (v && r != null && r != regionId && allRegions.any((x) => x.id == r)) {
      setRegion(r, movePickup: false);
    }
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

  /// Ориентир рядом с точкой подачи, например «Базар».
  String? pickupNear;
  bool pickupResolving = false;
  int _pickupAddrReq = 0;

  /// Растёт, когда точку подачи поменяли не движением карты — экран переносит туда карту.
  int pickupVersion = 0;

  void setPickup(LatLng p) {
    if (clientState != ClientState.home) return;
    if (Distance()(p, pickup) < 3) return;
    pickup = p;
    resolvePickupAddress();
    if (destPoint != null) _updateRoute();
    notifyListeners();
  }

  void setPickupPlace(String label, LatLng p) {
    pickup = p;
    fromAddress = label;
    pickupNear = null;
    pickupResolving = false;
    _pickupAddrReq++;
    pickupVersion++;
    if (destPoint != null) _updateRoute();
    notifyListeners();
  }

  Future<void> pickupFromGps() async {
    final p = await locateMe();
    if (p == null) return;
    pickup = p;
    pickupVersion++;
    resolvePickupAddress();
    if (destPoint != null) _updateRoute();
    notifyListeners();
  }

  Future<(String, String?)> _addressFor(LatLng p) async {
    final addr = await GeoApi.reverse(p);
    final near = nearestPlace(p, places)?.name;
    return (addr ?? tr('Точка на карте'), near);
  }

  Future<void> resolvePickupAddress() async {
    final req = ++_pickupAddrReq;
    final p = pickup;
    pickupResolving = true;
    notifyListeners();
    final (label, near) = await _addressFor(p);
    if (req != _pickupAddrReq) return;
    fromAddress = label;
    pickupNear = near;
    pickupResolving = false;
    notifyListeners();
  }

  // ─── Назначение и маршрут ───────────────────────────────────────────────
  LatLng? destPoint;
  RouteInfo? route;
  int _routeReq = 0;

  /// Растёт с каждым новым маршрутом — экран показывает маршрут целиком один раз.
  int routeVersion = 0;

  void setDestination(String label, LatLng point) {
    destination = label;
    destPoint = point;
    route = null;
    selectedPlace = null;
    pickMode = null;
    notifyListeners();
    _updateRoute();
  }

  void clearDestination() {
    destination = '';
    destPoint = null;
    route = null;
    _routeReq++;
    notifyListeners();
  }

  Future<void> _updateRoute() async {
    final to = destPoint;
    if (to == null) return;
    final req = ++_routeReq;
    final r = await GeoApi.route(pickup, to);
    if (req != _routeReq) return;
    route = r;
    routeVersion++;
    notifyListeners();
  }

  // ─── Машины на линии рядом с клиентом ───────────────────────────────────
  List<LatLng> onlineDrivers = [];
  StreamSubscription<List<Geo>>? _onlineSub;

  /// Минуты подачи ближайшей свободной машины; null — машин на линии нет.
  int? get pickupEtaMinutes {
    if (onlineDrivers.isEmpty) return null;
    final d = Distance();
    final m = onlineDrivers.map((c) => d(c, pickup)).reduce((a, b) => a < b ? a : b);
    return (m * 1.3 / 420).ceil().clamp(1, 999);
  }

  /// Время прибытия к месту назначения: подача + дорога.
  DateTime? get arrivalTime {
    final r = route;
    if (r == null) return null;
    return DateTime.now()
        .add(Duration(minutes: (pickupEtaMinutes ?? 3) + r.minutes));
  }

  // ─── «Указать на карте» ─────────────────────────────────────────────────
  /// 'to' — выбираем куда, 'from' — откуда; null — режим выключен.
  String? pickMode;
  LatLng? pickPoint;
  String? pickAddress;
  String? pickNear;
  int _pickReq = 0;

  void startPick(String mode) {
    pickMode = mode;
    pickPoint = null;
    pickAddress = null;
    pickNear = null;
    selectedPlace = null;
    notifyListeners();
  }

  Future<void> updatePick(LatLng p) async {
    if (pickMode == null) return;
    pickPoint = p;
    pickAddress = null;
    final req = ++_pickReq;
    notifyListeners();
    final (label, near) = await _addressFor(p);
    if (req != _pickReq) return;
    pickAddress = label;
    pickNear = near;
    notifyListeners();
  }

  void cancelPick() {
    pickMode = null;
    _pickReq++;
    notifyListeners();
  }

  void confirmPick() {
    final p = pickPoint;
    final mode = pickMode;
    if (p == null || mode == null) return;
    final label = pickAddress ?? tr('Точка на карте');
    pickMode = null;
    _pickReq++;
    if (mode == 'to') {
      setDestination(label, p);
    } else {
      setPickupPlace(label, p);
      pickupNear = pickNear;
    }
  }

  // ─── Карточка места, нажатого на карте ──────────────────────────────────
  Place? selectedPlace;

  void selectPlace(Place? p) {
    selectedPlace = p;
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
        toGeo: destPoint == null
            ? null
            : (lat: destPoint!.latitude, lng: destPoint!.longitude),
        region: regionId,
        tariff: tariff.name,
        price: tariff == Tariff.cargo ? (orderClientPrice ?? 0) : tariffPriceInt,
        payment: paymentMethod,
        clientPhone: authRepo.current?.phone ?? '',
        comment: orderComment,
        clientPrice: tariff == Tariff.cargo ? orderClientPrice : null,
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
    _seenBids = 0;
    _clientOrderSub?.cancel();
    _clientOrderSub = orders.watch(id).listen(_onClientOrder);
  }

  int _seenBids = 0;

  void _onClientOrder(TaxiOrder? o) {
    if (o == null) return;
    activeOrder = o;
    // Новое предложение цены от грузового водителя — сигнал клиенту.
    if (o.status == 'searching' && o.bids.length > _seenBids) playAlert();
    _seenBids = o.bids.length;
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
    orderComment = '';
    setClientState(ClientState.home);
    if (id != null) await orders.setStatus(id, 'cancelled');
  }

  /// Клиент выбрал предложение водителя (грузовое).
  Future<bool> chooseBid(Bid b) async {
    final id = activeOrderId;
    if (id == null) return false;
    return orders.chooseBid(id, b);
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
    destPoint = null;
    route = null;
    orderComment = '';
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
    // Грузовые заказы — только грузовым машинам, остальные — только легковым.
    final cargo = myDriver?.vehicle == 'cargo';
    for (final o in _searching) {
      if ((o.tariff == 'cargo') != cargo) continue;
      if (!_skipped.contains(o.id) && !_bidded.contains(o.id) && !o.declinedBy.contains(uid)) {
        return o;
      }
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
    final listen = isDriverMode && isOnline && driverCanWork;
    if (listen && _searchSub == null) {
      _searchSub = orders.watchSearching(regionId).listen((list) {
        _searching = list;
        notifyListeners();
      });
      _startGps();
      if (uid != null) {
        orders.setDriverOnline(uid!, true, regionId);
        _assignedSub?.cancel();
        _assignedSub = orders.watchAssigned(uid!).listen(_onAssigned, onError: (_) {});
      }
    } else if (!listen && _searchSub != null) {
      _searchSub!.cancel();
      _searchSub = null;
      _searching = [];
      _assignedSub?.cancel();
      _assignedSub = null;
      _gpsSub?.cancel();
      _gpsSub = null;
      if (uid != null) orders.setDriverOnline(uid!, false, regionId);
    }
  }

  StreamSubscription<List<TaxiOrder>>? _assignedSub;

  /// Менеджер назначил заказ (или после перезагрузки у водителя уже есть поездка) — показываем её.
  void _onAssigned(List<TaxiOrder> list) {
    if (driverOrder != null) return;
    for (final o in list) {
      if (o.status == 'accepted' || o.status == 'arrived' || o.status == 'riding') {
        if (o.status == 'accepted') playAlert();
        _followDriverOrder(o);
        return;
      }
    }
  }

  /// Почему не удалось получить координаты водителя; null — всё в порядке.
  String? gpsError;
  bool gpsRequesting = false;

  /// Машину поставили на карте руками (тест) — GPS её не сдвигает до «Повторить».
  bool manualLocation = false;

  void _startGps() {
    _gpsSub?.cancel();
    _gpsSub = LocationService.watch().listen(_onGps, onError: (Object e) {
      if (myLocation == null) gpsError = LocationService.describe(e);
      notifyListeners();
    });
    gpsRequesting = true;
    notifyListeners();
    // Первая точка сразу, не дожидаясь движения.
    LocationService.current().then((p) {
      gpsRequesting = false;
      if (p != null) {
        if (_gpsSub != null) _onGps(p);
      } else if (myLocation == null) {
        gpsError = LocationService.lastError ?? tr('Местоположение не получено.');
      }
      notifyListeners();
    });
  }

  void retryGps() {
    manualLocation = false;
    gpsError = null;
    if (_searchSub != null) {
      _startGps();
    } else {
      gpsRequesting = true;
      notifyListeners();
      LocationService.current().then((p) {
        gpsRequesting = false;
        if (p != null) {
          myLocation = p;
        } else {
          gpsError = LocationService.lastError ?? tr('Местоположение не получено.');
        }
        notifyListeners();
      });
    }
  }

  void setManualDriverLocation(LatLng p) {
    _simTimer?.cancel();
    _simTimer = null;
    manualLocation = true;
    myLocation = p;
    gpsError = null;
    if (uid != null) {
      orders.updateDriverLocation(uid!, (lat: p.latitude, lng: p.longitude));
    }
    notifyListeners();
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
    if (simulating || manualLocation) return;
    gpsError = null;
    myLocation = p;
    notifyListeners();
    final now = DateTime.now();
    if (uid == null || now.difference(_lastGpsSent).inSeconds < 4) return;
    _lastGpsSent = now;
    orders.updateDriverLocation(uid!, (lat: p.latitude, lng: p.longitude));
  }

  /// Грузовые заказы, где водитель уже предложил цену и ждёт ответа клиента.
  final Set<String> _bidded = {};
  int get waitingBids => _searching.where((o) => _bidded.contains(o.id)).length;

  Future<void> placeBid(TaxiOrder o, int price) async {
    final me = uid;
    if (me == null) return;
    _bidded.add(o.id);
    notifyListeners();
    await orders.placeBid(o.id, Bid(
      driverId: me,
      driverName: myDriver?.name.isNotEmpty == true ? myDriver!.name : await _myName(),
      car: myDriver?.car ?? '',
      plate: myDriver?.plate ?? '',
      price: price,
    ));
  }

  void skipOffer(String id) {
    _skipped.add(id);
    notifyListeners();
  }

  Future<void> acceptOffer(TaxiOrder o) async {
    if (uid == null) return;
    final ok = await orders.accept(o.id,
        driverId: uid!,
        driverName: myDriver?.name.isNotEmpty == true ? myDriver!.name : await _myName(),
        car: myDriver?.car,
        plate: myDriver?.plate);
    if (!ok) {
      skipOffer(o.id);
      return;
    }
    _followDriverOrder(o);
  }

  void _followDriverOrder(TaxiOrder o) {
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
    _onlineSub?.cancel();
    _settingsSub?.cancel();
    _streetsSub?.cancel();
    _placesSub?.cancel();
    _regionsSub?.cancel();
    _myDriverSub?.cancel();
    _assignedSub?.cancel();
    super.dispose();
  }

  // ─── Геттеры ─────────────────────────────────────────────────────────────
  String get tariffName {
    switch (tariff) {
      case Tariff.local:    return tr('Посёлок');
      case Tariff.border:   return 'Ушарал';
      case Tariff.whole:    return tr('Вся машина');
      case Tariff.delivery: return tr('Доставка');
      case Tariff.cargo:    return tr('Грузовое');
    }
  }

  /// Длина поездки: по дорогам, а пока маршрут не посчитан — по прямой.
  double? get tripMeters {
    final to = destPoint;
    if (to == null) return null;
    return route?.meters ?? Distance()(pickup, to);
  }

  bool get isFarTrip => (tripMeters ?? 0) > settings.farMeters;

  /// До Таможни/КПП и обратно — своя цена, вместо «дальше N км».
  bool get isKppTrip {
    final to = destPoint;
    if (to == null) return false;
    final d = Distance();
    for (final p in places) {
      if (p.category != 'kpp') continue;
      if (d(to, p.point) < 500 || d(pickup, p.point) < 500) return true;
    }
    return false;
  }

  int get localPriceInt => isKppTrip
      ? settings.kppPrice
      : isFarTrip ? settings.farPrice : settings.localPrice;

  String get tariffPrice => formatPrice(tariffPriceInt);

  /// Главное направление межгорода (первый другой район) и его цены.
  Region? get intercityTo => regions.where((r) => r.id != regionId).firstOrNull;
  RoutePrice get intercityPrice => settings.routeTo(intercityTo?.id ?? '');

  /// Одно направление — его название; несколько — «Межгород».
  String get intercityName {
    final n = regions.where((r) => r.id != regionId).length;
    return n == 1 ? intercityTo!.name : tr('Межгород');
  }

  /// Самые низкие цены среди направлений — для «от …» на карточке.
  bool get intercityMany => regions.where((r) => r.id != regionId).length > 1;
  int get intercityMinSeat => regions
      .where((r) => r.id != regionId)
      .map((r) => settings.routeTo(r.id).seat)
      .fold(intercityPrice.seat, (a, b) => a < b ? a : b);
  int get intercityMinWhole => regions
      .where((r) => r.id != regionId)
      .map((r) => settings.routeTo(r.id).whole)
      .fold(intercityPrice.whole, (a, b) => a < b ? a : b);

  int get tariffPriceInt {
    switch (tariff) {
      case Tariff.local:    return localPriceInt;
      case Tariff.border:   return intercityPrice.seat;
      case Tariff.whole:    return intercityPrice.whole;
      case Tariff.delivery: return settings.deliveryPrice;
      case Tariff.cargo:    return settings.cargoPrice;
    }
  }

  String get paymentLabel =>
      paymentMethod == 'kaspi' ? 'Kaspi' : tr('Наличные');
}

String formatPrice(int p) {
  final s = p.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b ₸';
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
