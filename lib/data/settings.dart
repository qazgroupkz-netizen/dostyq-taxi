/// Цены межгорода для одного направления (из этого района в другой).
class RoutePrice {
  final int seat;
  final int whole;
  final int parcel;
  const RoutePrice({required this.seat, required this.whole, required this.parcel});

  Map<String, int> toMap() => {'seat': seat, 'whole': whole, 'parcel': parcel};
}

/// Цены и правила сервиса. Значения по умолчанию — пока админ ничего не сохранил.
class TariffSettings {
  final int localPrice;
  final int kppPrice;
  final int farPrice;
  final int farMeters;
  final int seatPrice;
  final int wholeCarPrice;
  final int deliveryPrice;
  final int cargoPrice;
  final int parcelPrice;
  final int offerSeconds;
  final int showAllMinutes;
  final int freeWaitMinutes;
  final int subscriptionWeek;
  final int subscriptionMonth;

  /// Направление (id района назначения) → свои цены межгорода.
  final Map<String, RoutePrice> routes;

  const TariffSettings({
    this.localPrice = 500,
    this.kppPrice = 1500,
    this.farPrice = 2000,
    this.farMeters = 3000,
    this.seatPrice = 3500,
    this.wholeCarPrice = 14000,
    this.deliveryPrice = 400,
    this.cargoPrice = 3000,
    this.parcelPrice = 1500,
    this.offerSeconds = 20,
    this.showAllMinutes = 3,
    this.freeWaitMinutes = 5,
    this.subscriptionWeek = 4000,
    this.subscriptionMonth = 15000,
    this.routes = const {},
  });

  /// Цены направления; не заданы — общие цены межгорода этого района.
  RoutePrice routeTo(String to) =>
      routes[to] ?? RoutePrice(seat: seatPrice, whole: wholeCarPrice, parcel: parcelPrice);

  static const _d = TariffSettings();

  factory TariffSettings.fromMap(Map<String, dynamic> m) {
    int v(String k, int def) => (m[k] as num?)?.toInt() ?? def;
    final routes = <String, RoutePrice>{};
    final raw = m['routes'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final r = e.value;
        if (r is! Map) continue;
        routes['${e.key}'] = RoutePrice(
          seat: (r['seat'] as num?)?.toInt() ?? v('seatPrice', _d.seatPrice),
          whole: (r['whole'] as num?)?.toInt() ?? v('wholeCarPrice', _d.wholeCarPrice),
          parcel: (r['parcel'] as num?)?.toInt() ?? v('parcelPrice', _d.parcelPrice),
        );
      }
    }
    return TariffSettings(
      routes: routes,
      localPrice: v('localPrice', _d.localPrice),
      kppPrice: v('kppPrice', _d.kppPrice),
      farPrice: v('farPrice', _d.farPrice),
      farMeters: v('farMeters', _d.farMeters),
      seatPrice: v('seatPrice', _d.seatPrice),
      wholeCarPrice: v('wholeCarPrice', _d.wholeCarPrice),
      deliveryPrice: v('deliveryPrice', _d.deliveryPrice),
      cargoPrice: v('cargoPrice', _d.cargoPrice),
      parcelPrice: v('parcelPrice', _d.parcelPrice),
      offerSeconds: v('offerSeconds', _d.offerSeconds),
      showAllMinutes: v('showAllMinutes', _d.showAllMinutes),
      freeWaitMinutes: v('freeWaitMinutes', _d.freeWaitMinutes),
      subscriptionWeek: v('subscriptionWeek', _d.subscriptionWeek),
      subscriptionMonth: v('subscriptionMonth', _d.subscriptionMonth),
    );
  }

  Map<String, int> toMap() => {
        'localPrice': localPrice,
        'kppPrice': kppPrice,
        'farPrice': farPrice,
        'farMeters': farMeters,
        'seatPrice': seatPrice,
        'wholeCarPrice': wholeCarPrice,
        'deliveryPrice': deliveryPrice,
        'cargoPrice': cargoPrice,
        'parcelPrice': parcelPrice,
        'offerSeconds': offerSeconds,
        'showAllMinutes': showAllMinutes,
        'freeWaitMinutes': freeWaitMinutes,
        'subscriptionWeek': subscriptionWeek,
        'subscriptionMonth': subscriptionMonth,
      };
}
