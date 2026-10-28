import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../data/orders.dart';
import '../state.dart';
import '../theme.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../widgets/taxi_map.dart';

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
          primary: Color(0xFF2DB896),
          onPrimary: Color(0xFF06231C),
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
    const taxi = Color(0xFF2DB896);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Карта сзади
          TaxiMap(
            interactive: false,
            follow: state.myLocation,
            initialCenter: state.myLocation ?? dostykCenter,
            me: state.myLocation,
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
                            state.isOnline
                                ? 'На линии'
                                : 'Не в сети',
                            style: const TextStyle(
                              color: Color(0xFFA3ABB6),
                              fontSize: 13, fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(state.userName.isEmpty ? 'Водитель' : state.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21, fontWeight: FontWeight.w800,
                              )),
                        ],
                      ),
                      Row(
                        children: [
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
                                    state.isOnline ? 'На линии' : 'Оффлайн',
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

                        // Предупреждение о подписке
                        _SubWarning(),

                        const SizedBox(height: 16),

                        // Карточка заработка
                        _EarningsCard(),

                        const SizedBox(height: 16),

                        // Активный заказ или ожидание
                        if (state.driverOrder != null)
                          _ActiveRideCard(order: state.driverOrder!)
                        else if (!state.isOnline)
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

// ─── Предупреждение о подписке ──────────────────────────────────────────────
class _SubWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2A0B), Color(0xFF2A1F0A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6B4E14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFFD98A), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Подписка заканчивается',
                        style: TextStyle(
                          color: Color(0xFFFFD98A),
                          fontSize: 15, fontWeight: FontWeight.w700,
                        )),
                    SizedBox(height: 2),
                    Text(
                      'Ерлан, ваша подписка заканчивается через 2 дня. '
                      'Продлите, чтобы заказы не прекращались.',
                      style: TextStyle(
                        color: Color(0xFFE8D2A6),
                        fontSize: 13, height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          colors: [Color(0xFF1A2E28), Color(0xFF0F1A16)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF24614F).withOpacity(.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Сегодня',
              style: TextStyle(
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
            children: const [
              Expanded(child: _EarnStat(label: 'Поездок', value: '9')),
              Expanded(child: _EarnStat(label: 'Часов', value: '6,5')),
              Expanded(child: _EarnStat(label: 'Рейтинг', value: '4,9 ★')),
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
              color: const Color(0xFF2DB896).withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_tethering_rounded,
                color: Color(0xFF2DB896), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ждём заказ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w700,
                    )),
                SizedBox(height: 3),
                Text('Вы первый в очереди в вашем районе',
                    style: TextStyle(
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Вы не в сети',
                    style: TextStyle(
                      color: Color(0xFF5E6571),
                      fontSize: 16, fontWeight: FontWeight.w700,
                    )),
                SizedBox(height: 3),
                Text('Включите режим «На линии», чтобы получать заказы',
                    style: TextStyle(
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
      'whole'    => 'Вся машина',
      'delivery' => 'Доставка',
      _          => 'Посёлок',
    };

class _OfferCard extends StatefulWidget {
  final TaxiOrder order;
  const _OfferCard({super.key, required this.order});
  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  int _secs = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs--);
      if (_secs <= 0) {
        _timer?.cancel();
        context.read<AppState>().skipOffer(widget.order.id);
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final order = widget.order;
    final progress = (_secs / 20.0).clamp(0.0, 1.0);

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
              Text(_priceText(order.price),
                  style: const TextStyle(
                    color: Color(0xFF14171F),
                    fontSize: 28, fontWeight: FontWeight.w800,
                    letterSpacing: -.03 * 28,
                  )),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2EE),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(_tariffLabel(order.tariff),
                        style: const TextStyle(
                          color: Color(0xFF0A5C4C),
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
                              ? const Color(0xFF0E7C66)
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
            '${order.clientName.isEmpty ? 'Клиент' : order.clientName} · '
            '${order.payment == 'kaspi' ? 'Kaspi' : 'Наличные'}',
            style: const TextStyle(color: Color(0xFF5E6571), fontSize: 14),
          ),
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
                    child: const Text('Пропустить',
                        style: TextStyle(
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
                    _timer?.cancel();
                    state.acceptOffer(order);
                  },
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E7C66),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Принять',
                        style: TextStyle(
                          color: Colors.white,
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
                  color: const Color(0xFF0E7C66),
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
      'arrived' => ('Ждёте клиента', 'Поехали'),
      'riding'  => ('В пути', 'Завершить'),
      _         => ('Едете к клиенту', 'Я на месте'),
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181B21),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF24614F)),
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
                    color: Color(0xFF2DB896),
                    fontSize: 18, fontWeight: FontWeight.w800,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.clientName.isEmpty ? 'Клиент' : order.clientName} · '
            '${order.payment == 'kaspi' ? 'Kaspi' : 'Наличные'}',
            style: const TextStyle(color: Color(0xFFA3ABB6), fontSize: 14),
          ),
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
            const Text('Клиент выходит',
                style: TextStyle(
                  color: Color(0xFF2DB896),
                  fontSize: 15, fontWeight: FontWeight.w700,
                )),
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
                      child: const Text('Отменить',
                          style: TextStyle(
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
                      color: const Color(0xFF2DB896),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(action,
                        style: const TextStyle(
                          color: Color(0xFF06231C),
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
        color: isOn ? const Color(0xFF2DB896) : const Color(0xFF3A404A),
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
