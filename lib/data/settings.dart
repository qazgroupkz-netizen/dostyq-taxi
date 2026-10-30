/// Цены и правила сервиса. Значения по умолчанию — пока админ ничего не сохранил.
class TariffSettings {
  final int localPrice;
  final int kppPrice;
  final int farPrice;
  final int farMeters;
  final int seatPrice;
  final int wholeCarPrice;
  final int deliveryPrice;
  final int offerSeconds;
  final int showAllMinutes;
  final int freeWaitMinutes;
  final int subscriptionWeek;
  final int subscriptionMonth;

  const TariffSettings({
    this.localPrice = 500,
    this.kppPrice = 1500,
    this.farPrice = 2000,
    this.farMeters = 3000,
    this.seatPrice = 3500,
    this.wholeCarPrice = 14000,
    this.deliveryPrice = 400,
    this.offerSeconds = 20,
    this.showAllMinutes = 3,
    this.freeWaitMinutes = 5,
    this.subscriptionWeek = 4000,
    this.subscriptionMonth = 15000,
  });

  static const _d = TariffSettings();

  factory TariffSettings.fromMap(Map<String, dynamic> m) {
    int v(String k, int def) => (m[k] as num?)?.toInt() ?? def;
    return TariffSettings(
      localPrice: v('localPrice', _d.localPrice),
      kppPrice: v('kppPrice', _d.kppPrice),
      farPrice: v('farPrice', _d.farPrice),
      farMeters: v('farMeters', _d.farMeters),
      seatPrice: v('seatPrice', _d.seatPrice),
      wholeCarPrice: v('wholeCarPrice', _d.wholeCarPrice),
      deliveryPrice: v('deliveryPrice', _d.deliveryPrice),
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
        'offerSeconds': offerSeconds,
        'showAllMinutes': showAllMinutes,
        'freeWaitMinutes': freeWaitMinutes,
        'subscriptionWeek': subscriptionWeek,
        'subscriptionMonth': subscriptionMonth,
      };
}
