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
  String paymentMethod = 'cash'; // cash | kaspi

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

  // ─── Геттеры ─────────────────────────────────────────────────────────────
  String get tariffName {
    switch (tariff) {
      case Tariff.local:    return 'Посёлок';
      case Tariff.border:   return 'КПП';
      case Tariff.whole:    return 'Вся машина';
      case Tariff.delivery: return 'Доставка';
    }
  }

  String get tariffPrice {
    switch (tariff) {
      case Tariff.local:    return '500 ₸';
      case Tariff.border:   return '2 000 ₸';
      case Tariff.whole:    return '18 000 ₸';
      case Tariff.delivery: return '400 ₸';
    }
  }

  int get tariffPriceInt {
    switch (tariff) {
      case Tariff.local:    return 500;
      case Tariff.border:   return 2000;
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
  ('Больница', 'Ул. Молдагуловой, 14',   '🏥'),
  ('Рынок',    'Центральный рынок',       '🛒'),
  ('Школа №1', 'Ул. Достык, 1',          '🏫'),
  ('Мечеть',   'Ул. Молдагуловой, 32',   '🕌'),
  ('КПП',      'Граница (2 000 ₸)',       '🛃'),
  ('Почта',    'Ул. Сейткали',           '📬'),
  ('Аптека',   'Ул. Молдагуловой, 8',    '💊'),
  ('Детсад',   'Ул. Достык, 5',          '🧒'),
];
