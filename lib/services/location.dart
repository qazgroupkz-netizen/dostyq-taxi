import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../i18n.dart';

class LocationService {
  /// Понятная причина последней неудачи; null — последняя попытка удалась.
  static String? lastError;

  static Future<String?> _permissionError() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return tr('Службы геолокации выключены на устройстве.');
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return null;
      case LocationPermission.deniedForever:
        return tr('Доступ к геолокации запрещён навсегда — включите его в настройках.');
      default:
        return tr('Доступ к геолокации запрещён.');
    }
  }

  static String describe(Object e) {
    if (e is TimeoutException) {
      return tr('Устройство не сообщило координаты вовремя (таймаут).');
    }
    if (e is LocationServiceDisabledException) {
      return tr('Службы геолокации выключены на устройстве.');
    }
    if (e is PermissionDeniedException) {
      return tr('Доступ к геолокации запрещён.');
    }
    return trf('Ошибка геолокации: {e}', {'e': e});
  }

  static Future<LatLng?> current() async {
    lastError = null;
    try {
      final perr = await _permissionError();
      if (perr != null) {
        lastError = perr;
        return null;
      }
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } on TimeoutException {
        // Компьютер без GPS часто отвечает только на грубый запрос (по Wi-Fi).
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 20),
          ),
        );
      }
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      lastError = describe(e);
      return null;
    }
  }

  static Stream<LatLng> watch() async* {
    final perr = await _permissionError();
    if (perr != null) {
      lastError = perr;
      return;
    }
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map((p) => LatLng(p.latitude, p.longitude));
  }
}
