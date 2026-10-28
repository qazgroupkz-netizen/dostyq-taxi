import 'package:flutter/material.dart';

enum ClientState { home, seek, coming, arrived, ride, rate }
enum DriverState { offline, waiting, offer, active }
enum Tariff { local, border, whole, delivery }

class AppState extends ChangeNotifier {
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
  DriverState driverState = DriverState.waiting;
  bool isOnline = true;

  // ─── Сеттеры ────────────────────────────────────────────────────────────
  void setDriverMode(bool v) { isDriverMode = v; notifyListeners(); }
  void setTheme(ThemeMode m)  { themeMode = m;   notifyListeners(); }

  void setClientState(ClientState s) { clientState = s; notifyListeners(); }
  void setTariff(Tariff t)           { tariff = t;       notifyListeners(); }
  void setDestination(String d)      { destination = d;  notifyListeners(); }
  void setPayment(String p)          { paymentMethod = p; notifyListeners(); }

  void setDriverState(DriverState s) { driverState = s; notifyListeners(); }
  void toggleOnline() { isOnline = !isOnline; notifyListeners(); }
  void toggleSheet()  { sheetExpanded = !sheetExpanded; notifyListeners(); }

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
