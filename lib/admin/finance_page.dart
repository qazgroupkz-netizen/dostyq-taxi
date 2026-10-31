import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'admin_ui.dart';

/// Финансы: калькулятор дохода (как в reference/admin-prototype.html). Цифры хранятся в этом браузере.
class FinancePage extends StatefulWidget {
  const FinancePage({super.key});
  @override
  State<FinancePage> createState() => _FinancePageState();
}

const _def = <String, num>{
  'drivers': 20, 'orders': 20, 'days': 26, 'share': 20, 'pv': 500, 'pb': 2000, 'fuel': 2000,
  'fv': 30, 'fb': 100, 'sub': 4000, 'pct': 5, 'paying': 90, 'adsin': 30000,
  'server': 25000, 'platform': 60000, 'dev': 80000, 'manager': 0, 'ads': 20000, 'phone': 10000,
  'tax': 4, 'partner': 30, 'invest': 650000,
};
const _prefsKey = 'dostyq-admin-calc';

String _money(num n) {
  final r = n.round();
  final s = r.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  return '${r < 0 ? '−' : ''}$s ₸';
}

String _short(num n) {
  final a = n.abs();
  final s = n < 0 ? '−' : '';
  if (a >= 1e6) return '$s${(a / 1e6).toStringAsFixed(a >= 1e7 ? 1 : 2).replaceAll('.', ',')} млн';
  if (a >= 1e3) return '$s${(a / 1e3).round()} тыс';
  return '$s${a.round()}';
}

class _FinancePageState extends State<FinancePage> {
  final _v = Map<String, num>.of(_def);
  String _model = 'sub';
  bool _free1 = true;
  final _ctrl = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final k in _def.keys) {
      _ctrl[k] = TextEditingController(text: _fmt(_def[k]!));
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        for (final k in _def.keys) {
          final x = m[k];
          if (x is num) _v[k] = x;
        }
        if (m['model'] is String) _model = m['model'] as String;
        if (m['free1'] is bool) _free1 = m['free1'] as bool;
        for (final k in _def.keys) {
          _ctrl[k]!.text = _fmt(_v[k]!);
        }
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode({..._v, 'model': _model, 'free1': _free1}));
    } catch (_) {}
  }

  void _set(String k, num v, {bool syncField = true}) {
    setState(() {
      _v[k] = v;
      if (syncField) _ctrl[k]!.text = _fmt(v);
    });
    _save();
  }

  void _reset() {
    setState(() {
      _v
        ..clear()
        ..addAll(_def);
      _model = 'sub';
      _free1 = true;
      for (final k in _def.keys) {
        _ctrl[k]!.text = _fmt(_def[k]!);
      }
    });
    _save();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Цифры сброшены')));
  }

  // ─── Расчёт (формулы из прототипа) ───

  ({num inc, num tax, num cost, num part, num net}) _month(num fees) {
    final inc = fees + _v['adsin']!;
    final tax = inc * _v['tax']! / 100;
    final cost = _v['server']! + _v['platform']! + _v['dev']! + _v['manager']! + _v['ads']! + _v['phone']!;
    final b = inc - tax - cost;
    final p = b > 0 ? b * _v['partner']! / 100 : 0;
    return (inc: inc, tax: tax, cost: cost, part: p, net: b - p);
  }

  @override
  Widget build(BuildContext context) {
    final d = max<num>(0, _v['drivers']!);
    final dy = max<num>(0, _v['days']!);
    final sr = _v['share']!.clamp(0, 100) / 100;
    final trips = d * max<num>(0, _v['orders']!) * dy;
    final bo = trips * sr;
    final vi = trips - bo;
    final gmv = vi * _v['pv']! + bo * _v['pb']!;
    final pk = _v['paying']!.clamp(0, 100) / 100;
    num fees = switch (_model) {
      'fix' => vi * _v['fv']! + bo * _v['fb']!,
      'sub' => d * _v['sub']! * 52 / 12,
      _ => gmv * _v['pct']! / 100,
    };
    fees *= pk;
    final m = _month(fees);

    final dg = d > 0 ? gmv / d : 0;
    final df = d > 0 && pk > 0 ? fees / (d * pk) : 0;
    final pc = dg > 0 ? df / dg * 100 : 0;
    String? warn;
    if (pc > 12) {
      warn = 'Водитель отдаёт ${pc.toStringAsFixed(0)}% заработка. Это много, пока в WhatsApp-группе он не платит ничего.';
    } else if (m.net < 0) {
      warn = 'Расходы больше дохода. Помогает менеджер за долю или оплата за заявку, либо больше водителей.';
    }

    final f1 = _free1 ? _month(0) : m;
    final ser = <double>[];
    num cum = -_v['invest']!;
    int? pay;
    for (var i = 1; i <= 12; i++) {
      cum += i == 1 ? f1.net : m.net;
      ser.add(cum.toDouble());
      if (pay == null && cum >= 0) pay = i;
    }
    String tag;
    var tagBad = false;
    if (_v['invest']! <= 0) {
      tag = 'Без разовых вложений';
    } else if (m.net <= 0) {
      tag = 'Не окупается при этих цифрах';
      tagBad = true;
    } else if (pay != null) {
      tag = 'Окупится за $pay ${pay == 1 ? 'месяц' : pay < 5 ? 'месяца' : 'месяцев'}';
    } else {
      final mm = ((_v['invest']! - (f1.net - m.net)) / m.net).ceil();
      tag = 'Окупится примерно за $mm мес.';
    }

    final results = _results(context, m, trips, gmv, fees, dg, df, dy, warn, tag, tagBad, ser);
    final inputs = _inputs(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminHead(
          title: 'Финансы',
          sub: 'Калькулятор дохода: меняйте цифры, итог считается сразу',
          trailing: TextButton(onPressed: _reset, child: const Text('Сбросить')),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 1100
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: inputs),
                    const SizedBox(width: 12),
                    SizedBox(width: 400, child: results),
                  ],
                )
              : Column(children: [results, const SizedBox(height: 12), inputs]),
        ),
      ],
    );
  }

  // ─── Поля ───

  Widget _section(BuildContext context, IconData icon, String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: const Color(0xFFFFF4CC), borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, size: 16, color: const Color(0xFF8A6A00)),
                ),
                const SizedBox(width: 10),
                Text(title, style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
              ...children,
            ],
          ),
        ),
      );

  Widget _grid(List<Widget> fields) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 700 ? 3 : c.maxWidth > 420 ? 2 : 1;
          final w = (c.maxWidth - (cols - 1) * 14) / cols;
          return Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [for (final f in fields) SizedBox(width: w, child: f)],
          );
        }),
      );

  Widget _step(BuildContext context, String k, String label, num step,
      {String? unit, String? hint, num min = 0, num? maxV, Widget? extra}) {
    void bump(num delta) {
      var v = (_v[k]! + delta);
      if (v < min) v = min;
      if (maxV != null && v > maxV) v = maxV;
      _set(k, (v * 100).round() / 100);
    }

    Widget btn(String t, num delta) => SizedBox(
          width: 36,
          child: InkWell(
            onTap: () => bump(delta),
            child: Center(
              child: Text(t, style: TextStyle(color: context.muted, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: context.ink2, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: context.lineC),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              btn('−', -step),
              Expanded(
                child: TextField(
                  controller: _ctrl[k],
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                  ),
                  onChanged: (s) => _set(k, num.tryParse(s.replaceAll(',', '.').replaceAll(' ', '')) ?? 0,
                      syncField: false),
                ),
              ),
              if (unit != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(unit, style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              btn('+', step),
            ],
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(hint, style: const TextStyle(color: Color(0xFF8E939B), fontSize: 11.5)),
          ),
        if (extra != null) Padding(padding: const EdgeInsets.only(top: 6), child: extra),
      ],
    );
  }

  Widget _quick(BuildContext context, List<(String, num)> items, String k, {VoidCallback? after}) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (t, v) in items)
            Material(
              color: _v[k] == v ? context.ink : context.paper,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: _v[k] == v ? context.ink : context.lineC),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  _set(k, v);
                  after?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(t,
                      style: TextStyle(
                        color: _v[k] == v ? context.paper : context.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
            ),
        ],
      );

  Widget _inputs(BuildContext context) {
    Widget seg(String m, String t, String s) {
      final on = _model == m;
      return Expanded(
        child: Material(
          color: on ? context.paper : Colors.transparent,
          elevation: on ? 1 : 0,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () {
              setState(() => _model = m);
              _save();
            },
            child: SizedBox(
              height: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t, style: TextStyle(color: on ? context.ink : context.muted, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(s, style: TextStyle(color: on ? context.ink : context.muted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        _section(context, Icons.local_taxi_outlined, 'Водители и заказы', [
          _grid([
            _step(context, 'drivers', 'Водителей', 1, min: 1),
            _step(context, 'orders', 'Заказов в день у водителя', 1,
                extra: _quick(context, const [('15', 15), ('20', 20), ('25', 25), ('30', 30)], 'orders')),
            _step(context, 'days', 'Рабочих дней в месяц', 1, min: 1, maxV: 31),
            _step(context, 'share', 'Поездок до границы', 5, unit: '%', maxV: 100, hint: 'остальные по посёлку'),
            _step(context, 'pv', 'Цена по посёлку', 50, unit: '₸'),
            _step(context, 'pb', 'Цена до границы', 100, unit: '₸'),
            _step(context, 'fuel', 'Бензин водителя в день', 250, unit: '₸'),
          ]),
        ]),
        _section(context, Icons.payments_outlined, 'Как берём плату с водителей', [
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              seg('fix', 'За заказ', 'фикс ₸'),
              const SizedBox(width: 4),
              seg('sub', 'Подписка', 'в неделю'),
              const SizedBox(width: 4),
              seg('pct', 'Комиссия', '% от поездки'),
            ]),
          ),
          if (_model == 'fix')
            _grid([
              _step(context, 'fv', 'С поездки по посёлку', 10, unit: '₸'),
              _step(context, 'fb', 'С поездки до границы', 10, unit: '₸'),
            ]),
          if (_model == 'sub') _grid([_step(context, 'sub', 'Подписка в неделю', 500, unit: '₸')]),
          if (_model == 'pct') _grid([_step(context, 'pct', 'Комиссия', 1, unit: '%', maxV: 50)]),
          _grid([
            _step(context, 'paying', 'Реально платят', 5, unit: '%', maxV: 100, hint: 'кто-то болеет или не работает'),
            _step(context, 'adsin', 'Реклама магазинов', 5000, unit: '₸/мес'),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _free1,
              onChanged: (v) {
                setState(() => _free1 = v ?? false);
                _save();
              },
              title: const Text('Первый месяц для водителей бесплатно'),
            ),
          ),
        ]),
        _section(context, Icons.receipt_long_outlined, 'Расходы в месяц', [
          _grid([
            _step(context, 'server', 'Сервер и карты', 5000, unit: '₸'),
            _step(context, 'platform', 'Готовая платформа', 10000, unit: '₸', hint: '0, если своя разработка'),
            _step(context, 'dev', 'Программист', 10000, unit: '₸'),
            _step(context, 'manager', 'Менеджер', 10000, unit: '₸', hint: '0, если работает партнёр'),
            _step(context, 'ads', 'Реклама', 5000, unit: '₸'),
            _step(context, 'phone', 'Связь и прочее', 5000, unit: '₸'),
            _step(context, 'tax', 'Налог ИП', 1, unit: '%', maxV: 30, hint: 'уточните у бухгалтера'),
            _step(context, 'partner', 'Доля партнёра', 5, unit: '%', maxV: 100, hint: 'от прибыли'),
          ]),
        ]),
        _section(context, Icons.savings_outlined, 'Разовые вложения', [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _quick(
              context,
              const [('Готовая платформа · 650 тыс', 650000), ('Своя разработка · 6,15 млн', 6150000)],
              'invest',
              after: () {
                if (_v['invest']! > 1e6) {
                  _set('platform', 0);
                } else if (_v['platform'] == 0) {
                  _set('platform', 60000);
                }
              },
            ),
          ),
          _grid([
            _step(context, 'invest', 'Всего на старте', 50000,
                unit: '₸', hint: 'разработка, телефон, реклама на старте'),
          ]),
        ]),
      ],
    );
  }

  // ─── Итоги ───

  Widget _results(
    BuildContext context,
    ({num inc, num tax, num cost, num part, num net}) m,
    num trips,
    num gmv,
    num fees,
    num dg,
    num df,
    num dy,
    String? warn,
    String tag,
    bool tagBad,
    List<double> ser,
  ) {
    Widget row3(String l, String v) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l, style: const TextStyle(color: Color(0xFFA9AFB8), fontSize: 11.5)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );

    Widget ln(String l, String v, {Color? color, bool total = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: total ? null : Border(bottom: BorderSide(color: context.lineC)),
          ),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(color: context.muted, fontSize: 13.5))),
            Text(v,
                style: TextStyle(
                  color: color ?? context.ink,
                  fontSize: total ? 15 : 13.5,
                  fontWeight: FontWeight.w700,
                )),
          ]),
        );

    Widget drv(String l, String v) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l, style: TextStyle(color: context.muted, fontSize: 11.5)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(v, style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );

    const ok = Color(0xFF13A35A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1D23), Color(0xFF0E1014)],
            ),
            boxShadow: const [BoxShadow(color: Color(0x40111317), blurRadius: 30, offset: Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Вам чистыми в месяц', style: TextStyle(color: Color(0xFFA9AFB8), fontSize: 13)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_money(m.net),
                    style: TextStyle(
                      color: m.net < 0 ? const Color(0xFFFF7A7E) : Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                    )),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: tagBad ? const Color(0x26FF7A7E) : const Color(0x29FFD12E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tag,
                    style: TextStyle(
                      color: tagBad ? const Color(0xFFFF9C9F) : const Color(0xFFFFD12E),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              const SizedBox(height: 12),
              Row(children: [
                row3('Доход сервиса', '${_short(m.inc)} ₸'),
                const SizedBox(width: 8),
                row3('Расходы', '${_short(m.cost + m.tax)} ₸'),
                const SizedBox(width: 8),
                row3('Партнёру', '${_short(m.part)} ₸'),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Подробно за месяц', style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ln('Поездок у всех водителей', _money(trips).replaceAll(' ₸', '')),
              ln('Оборот всех водителей', _money(gmv)),
              ln('Плата водителей сервису', _money(fees)),
              ln('Реклама магазинов', _money(_v['adsin']!)),
              ln('Налог', '− ${_money(m.tax)}', color: context.muted),
              ln('Расходы', '− ${_money(m.cost)}', color: context.muted),
              ln('Доля партнёра', '− ${_money(m.part)}', color: context.muted),
              ln('Вам чистыми', _money(m.net), color: ok, total: true),
              const SizedBox(height: 16),
              Text('Один водитель в месяц', style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [
                drv('Зарабатывает', '${_short(dg)} ₸'),
                const SizedBox(width: 8),
                drv('Платит вам', '${_short(df)} ₸'),
                const SizedBox(width: 8),
                drv('После бензина', '${_short(dg - df - _v['fuel']! * dy)} ₸'),
              ]),
              if (warn != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF1DE), borderRadius: BorderRadius.circular(12)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFC26A00)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(warn,
                          style: const TextStyle(
                              color: Color(0xFFC26A00), fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                    ),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Деньги за первый год', style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Накопленный плюс или минус с учётом вложений',
                  style: TextStyle(color: context.muted, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              SizedBox(
                height: 190,
                width: double.infinity,
                child: CustomPaint(painter: _YearChart(ser, _v['invest']!.toDouble(), context.ink, context.muted, context.lineC)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Прикидка для планирования, не финансовая консультация. Месяц = 52/12 недели.',
            style: TextStyle(color: context.muted, fontSize: 12, height: 1.5)),
      ],
    );
  }
}

/// Накопленная прибыль за 12 месяцев: выше нуля — зелёным, ниже — красным.
class _YearChart extends CustomPainter {
  final List<double> ser;
  final double invest;
  final Color ink;
  final Color muted;
  final Color grid;
  _YearChart(this.ser, this.invest, this.ink, this.muted, this.grid);

  static const _ok = Color(0xFF13A35A);
  static const _bad = Color(0xFFD93A3F);

  void _text(Canvas c, String t, Offset at, {TextAlign align = TextAlign.left, double size = 11,
      FontWeight w = FontWeight.w400, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color ?? muted, fontSize: size, fontWeight: w)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right || TextAlign.end => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size s) {
    const pl = 46.0, pr = 12.0, pt = 14.0, pb = 24.0;
    final vals = [...ser, -invest, 0.0];
    var mx = vals.reduce(max), mn = vals.reduce(min);
    if (mx == mn) mx += 1;
    final sp = mx - mn;
    mx += sp * .08;
    mn -= sp * .08;
    double x(num i) => pl + i / 12 * (s.width - pl - pr);
    double y(double v) => pt + (s.height - pt - pb) * (mx - v) / (mx - mn);
    final z = y(0);

    for (final (k, v) in [(0, mx - (mx - mn) * .08), (1, 0.0), (2, mn + (mx - mn) * .08)]) {
      final yy = y(v);
      if (k != 1 && (yy - z).abs() < 14) continue;
      final p = Paint()
        ..color = grid
        ..strokeWidth = k == 1 ? 1.5 : 1;
      if (k == 1) {
        canvas.drawLine(Offset(pl, yy), Offset(s.width - pr, yy), p);
      } else {
        for (var xx = pl; xx < s.width - pr; xx += 7) {
          canvas.drawLine(Offset(xx, yy), Offset(min(xx + 3, s.width - pr), yy), p);
        }
      }
      _text(canvas, _short(v), Offset(pl - 6, yy), align: TextAlign.right);
    }

    final pts = [Offset(x(0), y(-invest)), for (var i = 0; i < ser.length; i++) Offset(x(i + 1), y(ser[i]))];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(x(12), z)
      ..lineTo(x(0), z)
      ..close();
    final up = Rect.fromLTWH(0, 0, s.width, max(0, z));
    final down = Rect.fromLTWH(0, z, s.width, max(0, s.height - z));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.clipRect(up);
    canvas.drawPath(area, Paint()..color = _ok.withOpacity(.16));
    stroke.color = _ok;
    canvas.drawPath(line, stroke);
    canvas.restore();
    canvas.save();
    canvas.clipRect(down);
    canvas.drawPath(area, Paint()..color = _bad.withOpacity(.12));
    stroke.color = _bad;
    canvas.drawPath(line, stroke);
    canvas.restore();

    for (final i in [1, 3, 6, 9, 12]) {
      _text(canvas, '$i мес', Offset(x(i), s.height - 8), align: TextAlign.center);
    }
    if (ser.isNotEmpty) {
      final l = ser.last;
      final p = Offset(x(12), y(l));
      canvas.drawCircle(p, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4.5, Paint()..color = l >= 0 ? _ok : _bad);
      _text(canvas, '${_short(l)} ₸', Offset(p.dx - 8, p.dy + (p.dy < pt + 20 ? 16 : -10)),
          align: TextAlign.right, size: 12.5, w: FontWeight.w700, color: ink);
    }
  }

  @override
  bool shouldRepaint(_YearChart old) => old.ser != ser || old.invest != invest;
}
