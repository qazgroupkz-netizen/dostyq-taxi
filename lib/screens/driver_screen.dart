import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../data/orders.dart';
import '../services/sound.dart';
import 'driver_trips_screen.dart';
import '../state.dart';
import '../theme.dart';
import 'package:flutter_map/flutter_map.dart' show MapController;
import 'package:latlong2/latlong.dart' show LatLng;
import '../config.dart';
import '../i18n.dart';
import '../data/places.dart';
import '../widgets/taxi_map.dart';
import '../widgets/report_sheet.dart';

// ════════════════════════════════════════════════════════════════
//  Экран водителя (всегда тёмная тема)
// ════════════════════════════════════════════════════════════════
class DriverScreen extends StatelessWidget {
  const DriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Всегда тёмный экран
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD12E),
          onPrimary: Color(0xFF111317),
          surface: Color(0xFF181B21),
        ),
      ),
      child: const _DriverBody(),
    );
  }
}

class _DriverBody extends StatelessWidget {
  const _DriverBody();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    const bg   = Color(0xFF0F1115);
    const taxi = Color(0xFFFFD12E);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Карта сзади
          TaxiMap(
            interactive: false,
            follow: state.myLocation,
            initialCenter: state.myLocation ?? state.region.center,
            me: state.driverOrder == null ? state.myLocation : null,
            car: state.driverOrder == null ? null : state.myLocation,
            pickup: state.driverOrder?.fromLat == null
                ? null
                : LatLng(state.driverOrder!.fromLat!, state.driverOrder!.fromLng!),
          ),
          // Затемнение вместо Opacity: дешевле, чем перерисовывать карту полупрозрачной.
          const IgnorePointer(
            child: ColoredBox(
              color: Color(0x990F1115),
              child: SizedBox.expand(),
            ),
          ),

          // Контент
          SafeArea(
            child: Column(
              children: [
                // Верхняя панель
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${state.isOnline ? tr('На линии') : tr('Не в сети')} · ${state.region.name}',
                            style: const TextStyle(
                              color: Color(0xFFA3ABB6),
                              fontSize: 13, fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(state.userName.isEmpty ? tr('Водитель') : state.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21, fontWeight: FontWeight.w800,
                              )),
                        ],
                      ),
                      Row(
                        children: [
                          // Язык интерфейса
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              tooltip: 'Тіл / Язык',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1F232A),
                                fixedSize: const Size(46, 46),
                              ),
                              icon: const Icon(Icons.language, color: Color(0xFFFFD12E)),
                              onPressed: () => pickLanguage(context),
                            ),
                          ),
                          // Межгород: рейсы этого водителя
                          if (state.driverCanWork)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: IconButton(
                                tooltip: tr('Мои рейсы'),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF1F232A),
                                  fixedSize: const Size(46, 46),
                                ),
                                icon: const Icon(Icons.route_rounded, color: Color(0xFFFFD12E)),
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const DriverTripsScreen(),
                                )),
                              ),
                            ),
                          // Переключатель «На линии»
                          GestureDetector(
                            onTap: () => state.toggleOnline(),
                            child: Container(
                              height: 46,
                              padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F232A),
                                borderRadius: BorderRadius.circular(23),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    state.isOnline ? tr('На линии') : tr('Оффлайн'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14, fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _Toggle(isOn: state.isOnline),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        if (state.isOnline && state.myLocation == null) ...[
                          const _NoGpsWarning(),
                          const SizedBox(height: 12),
                        ] else if (kTestMode) ...[
                          const _ManualPlaceLink(),
                          const SizedBox(height: 12),
                        ],

                        // Предупреждение о подписке
                        const _SubWarning(),

                        const SizedBox(height: 16),

                        // Карточка заработка
                        _EarningsCard(),

                        const SizedBox(height: 16),

                        if (state.driverOrder == null && state.waitingBids > 0)
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F232A),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              trf('Ваши цены отправлены ({n}). Если клиент выберет вас — заказ откроется со звуком.',
                                  {'n': state.waitingBids}),
                              style: const TextStyle(color: Color(0xFFFFD98A), fontSize: 13.5, height: 1.4),
                            ),
                          ),

                        // Активный заказ или ожидание
                        if (state.driverOrder != null)
                          _ActiveRideCard(order: state.driverOrder!)
                        else if (!state.isOnline || !state.driverCanWork)
                          _OfflineCard()
                        else if (state.offer != null)
                          _OfferCard(
                              key: ValueKey(state.offer!.id),
                              order: state.offer!)
                        else
                          _WaitingCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Кнопка «Назад»
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 4,
            child: BackButton(
              color: Colors.white,
              onPressed: () {
                context.read<AppState>().setDriverMode(false);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoGpsWarning extends StatelessWidget {
  const _NoGpsWarning();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1416),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_off_rounded, color: Color(0xFFFF8A8E), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Местоположение не определено — клиенты не увидят вашу машину.'),
                  style: const TextStyle(
                    color: Color(0xFFF2C9CB),
                    fontSize: 14, fontWeight: FontWeight.w700, height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.gpsRequesting
                ? tr('Запрашиваем местоположение…')
                : trf('Причина: {e}', {'e': state.gpsError ?? tr('ответа от устройства ещё нет.')}),
            style: const TextStyle(color: Color(0xFFE8A9AC), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          _DarkButton(
            label: state.gpsRequesting ? tr('Ждём ответа…') : tr('Повторить'),
            icon: Icons.refresh_rounded,
            onTap: state.gpsRequesting ? null : state.retryGps,
          ),
          if (kTestMode) ...[
            const SizedBox(height: 8),
            _DarkButton(
              label: tr('Поставить машину на карте вручную'),
              icon: Icons.edit_location_alt_outlined,
              onTap: () => _openManualPlace(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManualPlaceLink extends StatelessWidget {
  const _ManualPlaceLink();

  @override
  Widget build(BuildContext context) {
    final manual = context.select<AppState, bool>((s) => s.manualLocation);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _DarkButton(
              label: manual ? tr('Тест: машина поставлена вручную — сдвинуть')
                  : tr('Тест: поставить машину вручную'),
              icon: Icons.edit_location_alt_outlined,
              onTap: () => _openManualPlace(context),
            ),
          ),
          if (manual) ...[
            const SizedBox(width: 8),
            _DarkButton(
              label: 'GPS',
              icon: Icons.gps_fixed_rounded,
              onTap: context.read<AppState>().retryGps,
            ),
          ],
        ],
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _DarkButton({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F232A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2F37)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD98A), size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                    color: onTap == null ? const Color(0xFF5E6571) : const Color(0xFFFFD98A),
                    fontSize: 14.5, fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

void _openManualPlace(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => const _ManualPlaceScreen(),
    fullscreenDialog: true,
  ));
}

class _ManualPlaceScreen extends StatefulWidget {
  const _ManualPlaceScreen();
  @override
  State<_ManualPlaceScreen> createState() => _ManualPlaceScreenState();
}

class _ManualPlaceScreenState extends State<_ManualPlaceScreen> {
  final _map = MapController();

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(
        children: [
          TaxiMap(
            controller: _map,
            centerPin: true,
            pinLabel: tr('Машина здесь'),
            initialCenter: state.myLocation ?? state.region.center,
            places: state.places,
          ),
          Positioned(
            top: top + 12, left: 12,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF14171F)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Positioned(
            left: 16, right: 16, bottom: bottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    tr('Тест: двигайте карту, чтобы булавка стояла там, где машина'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF14171F), fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD12E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      state.setManualDriverLocation(_map.camera.center);
                      Navigator.of(context).pop();
                    },
                    child: Text(tr('Поставить машину здесь'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Подписка: напоминание за 3 дня, за 1 день, в день окончания и после ────
class _SubWarning extends StatelessWidget {
  const _SubWarning();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.myDriver;
    final days = p?.subscriptionDaysLeft;
    if (p == null || days == null || days > 3) return const SizedBox.shrink();

    final expired = !p.subscriptionActive;
    final name = p.name.isEmpty ? '' : '${p.name.split(' ').first}, ';
    final title = expired
        ? tr('Подписка закончилась')
        : days == 0
            ? tr('Подписка заканчивается сегодня')
            : tr('Подписка заканчивается');
    final when = days == 1 ? tr('завтра') : trf('через {d} дня', {'d': days});
    final s = state.settings;
    final pay = trf(
        'Оплатите {w} в неделю или {m} в месяц через Kaspi на счёт ИП '
        'и сообщите администратору.',
        {'w': formatPrice(s.subscriptionWeek), 'm': formatPrice(s.subscriptionMonth)});
    final text = expired
        ? '$name${tr('заказы не приходят, пока подписка не продлена.')} $pay'
        : days == 0
            ? '$name${tr('сегодня последний день подписки.')} $pay'
            : '$name${trf('ваша подписка заканчивается {when}.', {'when': when})} $pay';
    final bad = expired || days == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bad
              ? const [Color(0xFF3A1416), Color(0xFF2A0F10)]
              : const [Color(0xFF3A2A0B), Color(0xFF2A1F0A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bad ? const Color(0xFF7A2A2E) : const Color(0xFF6B4E14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: bad ? const Color(0xFFFF8A8E) : const Color(0xFFFFD98A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: bad ? const Color(0xFFFF8A8E) : const Color(0xFFFFD98A),
                      fontSize: 15, fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(text,
                    style: const TextStyle(
                      color: Color(0xFFE8D2A6), fontSize: 13, height: 1.4,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ─── Карточка заработка ──────────────────────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF262A31), Color(0xFF17191E)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6B5A1E).withOpacity(.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Сегодня'),
              style: const TextStyle(
                color: Color(0xFFA3ABB6),
                fontSize: 13, fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 4),
          const Text('4 500 ₸',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38, fontWeight: FontWeight.w800,
                letterSpacing: -.04 * 38, height: 1.05,
              )),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _EarnStat(label: tr('Поездок'), value: '9')),
              Expanded(child: _EarnStat(label: tr('Часов'), value: '6,5')),
              Expanded(child: _EarnStat(label: tr('Рейтинг'), value: '4,9 ★')),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarnStat extends StatelessWidget {
  final String label, value;
  const _EarnStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: Color(0xFFA3ABB6),
                fontSize: 11.5, fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

// ─── Ожидание заказа ──────────────────────────────────────────────────────
class _WaitingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181B21),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2A2F37)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD12E).withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_tethering_rounded,
                color: Color(0xFFFFD12E), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Ждём заказ'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 3),
                Text(tr('Вы первый в очереди в вашем районе'),
                    style: const TextStyle(
                      color: Color(0xFFC3C8D0),
                      fontSize: 13.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Офлайн ──────────────────────────────────────────────────────────────────
class _OfflineCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181B21),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2A2F37)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2F37),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: Color(0xFF5E6571), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Вы не в сети'),
                    style: const TextStyle(
                      color: Color(0xFF5E6571),
                      fontSize: 16, fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 3),
                Text(tr('Включите режим «На линии», чтобы получать заказы'),
                    style: const TextStyle(
                      color: Color(0xFF5E6571),
                      fontSize: 13.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Карточка нового заказа с таймером ──────────────────────────────────────
String _priceText(int p) {
  final s = p.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b ₸';
}

String _tariffLabel(String t) => switch (t) {
      'border'   => 'Ушарал',
      'whole'    => tr('Вся машина'),
      'delivery' => tr('Доставка'),
      'cargo'    => tr('Грузовое'),
      _          => tr('Посёлок'),
    };

class _OfferCard extends StatefulWidget {
  final TaxiOrder order;
  const _OfferCard({super.key, required this.order});
  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  // Грузовое — торг, даём больше времени подумать над ценой.
  late int _total = widget.order.tariff == 'cargo'
      ? 60
      : context.read<AppState>().settings.offerSeconds;
  late int _secs = _total;
  Timer? _timer;
  final _price = TextEditingController();

  bool get _cargo => widget.order.tariff == 'cargo';

  @override
  void initState() {
    super.initState();
    final suggest = widget.order.clientPrice ?? context.read<AppState>().settings.cargoPrice;
    _price.text = '$suggest';
    playAlert();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs--);
      if (_secs > 0 && _secs % 5 == 0) playAlert();
      if (_secs <= 0) {
        _timer?.cancel();
        context.read<AppState>().skipOffer(widget.order.id);
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); _price.dispose(); super.dispose(); }

  void _bid(AppState state) {
    final p = int.tryParse(_price.text.replaceAll(RegExp(r'\D'), ''));
    if (p == null || p <= 0) return;
    _timer?.cancel();
    state.placeBid(widget.order, p);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final order = widget.order;
    final progress = (_secs / _total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Цена + таймер
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                    _cargo
                        ? (order.clientPrice == null
                            ? tr('Цену предложите вы')
                            : trf('Клиент: {p}', {'p': _priceText(order.clientPrice!)}))
                        : _priceText(order.price),
                    style: TextStyle(
                      color: const Color(0xFF14171F),
                      fontSize: _cargo ? 20 : 28, fontWeight: FontWeight.w800,
                      letterSpacing: -.03 * 28,
                    )),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6D1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(_tariffLabel(order.tariff),
                        style: const TextStyle(
                          color: Color(0xFF6B5200),
                          fontSize: 12.5, fontWeight: FontWeight.w700,
                        )),
                  ),
                  const SizedBox(width: 10),
                  // Круговой таймер
                  SizedBox(
                    width: 46, height: 46,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0xFFE1E4DE),
                          color: progress > .3
                              ? const Color(0xFFFFD12E)
                              : const Color(0xFFD93F44),
                          strokeWidth: 4,
                        ),
                        Text('$_secs',
                            style: const TextStyle(
                              color: Color(0xFF14171F),
                              fontSize: 14, fontWeight: FontWeight.w800,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Маршрут
          _OfferRoute(from: order.from, to: order.to),
          const SizedBox(height: 8),
          Text(
            '${order.clientName.isEmpty ? tr('Клиент') : order.clientName} · '
            '${order.payment == 'kaspi' ? 'Kaspi' : tr('Наличные')}',
            style: const TextStyle(color: Color(0xFF5E6571), fontSize: 14),
          ),
          if (order.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${order.tariff == 'cargo' ? tr('Груз') : tr('Заказ')}: ${order.comment}',
                style: const TextStyle(
                  color: Color(0xFF14171F), fontSize: 15, fontWeight: FontWeight.w700,
                )),
          ],
          if (_cargo) ...[
            const SizedBox(height: 14),
            Text(tr('Ваша цена'),
                style: const TextStyle(color: Color(0xFF5E6571), fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Color(0xFF14171F), fontSize: 22, fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      suffixText: '₸',
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                for (final add in const [500, 1000])
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: OutlinedButton(
                      onPressed: () {
                        final p = int.tryParse(_price.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
                        setState(() => _price.text = '${p + add}');
                      },
                      child: Text('+$add'),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          // Кнопки
          Row(
            children: [
              // Пропустить
              Expanded(
                child: GestureDetector(
                  onTap: () => state.skipOffer(order.id),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E7EA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(tr('Пропустить'),
                        style: const TextStyle(
                          color: Color(0xFF14171F),
                          fontSize: 16, fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Принять
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    if (_cargo) {
                      _bid(state);
                      return;
                    }
                    _timer?.cancel();
                    state.acceptOffer(order);
                  },
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD12E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(_cargo ? tr('Предложить цену') : tr('Принять'),
                        style: const TextStyle(
                          color: Color(0xFF111317),
                          fontSize: 16, fontWeight: FontWeight.w700,
                        )),
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

class _OfferRoute extends StatelessWidget {
  final String from, to;
  const _OfferRoute({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OfferRouteRow(isDot: true,  label: from),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Container(
            width: 1, height: 16,
            color: const Color(0xFFCDD2CA),
          ),
        ),
        _OfferRouteRow(isDot: false, label: to),
      ],
    );
  }
}

class _OfferRouteRow extends StatelessWidget {
  final bool isDot;
  final String label;
  const _OfferRouteRow({required this.isDot, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        isDot
            ? Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF14171F),
                  borderRadius: BorderRadius.circular(5),
                ))
            : Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD12E),
                  borderRadius: BorderRadius.circular(3),
                )),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label.isEmpty ? '—' : label,
              style: const TextStyle(
                color: Color(0xFF14171F),
                fontSize: 15, fontWeight: FontWeight.w600,
              )),
        ),
      ],
    );
  }
}

// ─── Активная поездка ──────────────────────────────────────────────────────
class _ActiveRideCard extends StatelessWidget {
  final TaxiOrder order;
  const _ActiveRideCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final (title, action) = switch (order.status) {
      'arrived' => (tr('Ждёте клиента'), tr('Поехали')),
      'riding'  => (tr('В пути'), tr('Завершить')),
      _         => (tr('Едете к клиенту'), tr('Я на месте')),
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181B21),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6B5A1E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w800,
                  )),
              Text(_priceText(order.price),
                  style: const TextStyle(
                    color: Color(0xFFFFD12E),
                    fontSize: 18, fontWeight: FontWeight.w800,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.clientName.isEmpty ? tr('Клиент') : order.clientName} · '
            '${order.payment == 'kaspi' ? 'Kaspi' : tr('Наличные')}',
            style: const TextStyle(color: Color(0xFFA3ABB6), fontSize: 14),
          ),
          if (order.comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${order.tariff == 'cargo' ? tr('Груз') : tr('Заказ')}: ${order.comment}',
                style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700,
                )),
          ],
          if (order.clientPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(
              '${trf('Телефон клиента: {p}', {'p': order.clientPhone})}'
              '${order.createdBy == 'manager' ? ' · ${tr('заказ по звонку')}' : ''}',
              style: const TextStyle(
                color: Color(0xFFFFD98A), fontSize: 15, fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _OfferRoute(from: order.from, to: order.to),
          ),
          if (order.status == 'arrived' && order.clientComingOut) ...[
            const SizedBox(height: 10),
            Text(tr('Клиент выходит'),
                style: const TextStyle(
                  color: Color(0xFFFFD12E),
                  fontSize: 15, fontWeight: FontWeight.w700,
                )),
          ],
          if (order.status == 'accepted' && order.fromLat != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: state.simulating ? state.stopSimulation : state.startSimulation,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F232A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A2F37)),
                ),
                alignment: Alignment.center,
                child: Text(
                  state.simulating
                      ? '■  ${tr('Остановить демо-поездку')}'
                      : '▶  ${tr('Демо: поехать к клиенту')}',
                  style: const TextStyle(
                    color: Color(0xFFFFD98A),
                    fontSize: 14, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (order.status != 'riding') ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => state.driverCancel(),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F232A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2A2F37)),
                      ),
                      alignment: Alignment.center,
                      child: Text(tr('Отменить'),
                          style: const TextStyle(
                            color: Color(0xFFD93F44),
                            fontSize: 16, fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => state.advanceRide(),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD12E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(action,
                        style: const TextStyle(
                          color: Color(0xFF111317),
                          fontSize: 16, fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: () => showComplaintSheet(context, fromDriver: true, order: order),
              child: Text(tr('Пожаловаться на клиента'),
                  style: const TextStyle(color: Color(0xFFA3ABB6), fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Переключатель «тумблер» ─────────────────────────────────────────────────
class _Toggle extends StatelessWidget {
  final bool isOn;
  const _Toggle({required this.isOn});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50, height: 30,
      decoration: BoxDecoration(
        color: isOn ? const Color(0xFFFFD12E) : const Color(0xFF3A404A),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
