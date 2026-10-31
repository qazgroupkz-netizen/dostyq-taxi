import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/orders.dart';
import '../i18n.dart';
import '../services/open_link.dart';
import '../state.dart';
import '../theme.dart';

void _snack(BuildContext context, String t) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

String _orderLine(TaxiOrder? o) => o == null
    ? ''
    : [
        if ((o.driverName ?? '').isNotEmpty) 'Водитель ${o.driverName}',
        if ((o.driverPlate ?? '').isNotEmpty) o.driverPlate!,
        if (o.clientName.isNotEmpty) 'клиент ${o.clientName}',
        '${o.from} → ${o.to.isEmpty ? '—' : o.to}',
      ].join(', ');

/// Клиент в поездке нажал «Помощь»: SOS диспетчеру и звонок 112.
Future<void> showSosSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Нужна помощь?'),
                  style: TextStyle(color: context.ink, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(tr('Диспетчер сразу увидит ваш заказ и водителя и перезвонит вам.'),
                  style: TextStyle(color: context.muted, fontSize: 15, height: 1.4)),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: () async {
                  final state = context.read<AppState>();
                  Navigator.pop(ctx);
                  try {
                    await state.reportIncident('sos', 'SOS: клиент нажал кнопку помощи',
                        body: _orderLine(state.activeOrder), orderId: state.activeOrderId);
                    if (context.mounted) _snack(context, tr('Сигнал отправлен. Диспетчер скоро позвонит.'));
                  } catch (_) {
                    if (context.mounted) _snack(context, tr('Не отправилось. Позвоните 112.'));
                  }
                },
                child: Text(tr('SOS — сообщить диспетчеру'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () {
                  if (!openLink('tel:112')) _snack(context, tr('Наберите 112'));
                },
                child: Text(tr('Позвонить 112'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );

/// Жалоба по заказу: клиент — на водителя, водитель — на клиента.
Future<void> showComplaintSheet(BuildContext context, {required bool fromDriver, TaxiOrder? order}) async {
  final reasons = fromDriver
      ? ['Клиент не вышел', 'Не заплатил', 'Грубил', 'Другое']
      : ['Взял больше цены', 'Грубил', 'Опасно водил', 'Долго ехал', 'Другое'];
  var reason = reasons.first;
  final text = TextEditingController();
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(fromDriver ? tr('Пожаловаться на клиента') : tr('Пожаловаться на поездку'),
                style: TextStyle(color: ctx.ink, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in reasons)
                  ChoiceChip(
                    label: Text(tr(r)),
                    selected: r == reason,
                    onSelected: (_) => setSt(() => reason = r),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: text,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr('Что случилось? Можно коротко'),
                filled: true,
                fillColor: ctx.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Отправить'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    ),
  );
  if (sent != true || !context.mounted) return;
  final who = fromDriver ? 'водитель на клиента' : 'клиент на водителя';
  final body = [text.text.trim(), _orderLine(order)].where((s) => s.isNotEmpty).join('. ');
  try {
    await context.read<AppState>().reportIncident('complaint', 'Жалоба ($who): ${reason.toLowerCase()}',
        body: body, orderId: order?.id);
    if (context.mounted) _snack(context, tr('Жалоба отправлена. Спасибо!'));
  } catch (_) {
    if (context.mounted) _snack(context, tr('Не отправилось, попробуйте ещё раз'));
  }
}
