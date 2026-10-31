import 'package:flutter/material.dart';
import '../data/orders.dart';
import '../theme.dart';
import 'admin_ui.dart';

String hm(DateTime? t) => t == null
    ? '--:--'
    : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// «Сегодня, 14:05», «Вчера, 09:12» или «28.10, 18:40».
String dayTime(DateTime? t) {
  if (t == null) return '—';
  final now = DateTime.now();
  final d = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final day = d == today
      ? 'Сегодня'
      : d == today.subtract(const Duration(days: 1))
          ? 'Вчера'
          : '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}';
  return '$day, ${hm(t)}';
}

/// Короткий номер для поиска и разговора: последние 4 знака id.
String shortNo(TaxiOrder o) =>
    '#${(o.id.length > 4 ? o.id.substring(o.id.length - 4) : o.id).toUpperCase()}';

String serviceName(String tariff) => switch (tariff) {
      'local' => 'По посёлку',
      'border' => 'Таможня · КПП',
      'whole' => 'Межгород',
      'delivery' => 'Доставка',
      'cargo' => 'Грузовое',
      _ => tariff,
    };

/// Статус заказа таблеткой с точкой (как в прототипе админки).
class OrderPill extends StatelessWidget {
  final String status;
  const OrderPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, _) = orderStatus(context, status);
    final tone = switch (status) {
      'searching' => PillTone.warn,
      'accepted' || 'arrived' => PillTone.info,
      'riding' => PillTone.violet,
      'done' => PillTone.ok,
      'cancelled' => PillTone.bad,
      _ => PillTone.mute,
    };
    return StatusPill(label, tone);
  }
}

(String, Color) orderStatus(BuildContext context, String s) => switch (s) {
      'searching' => ('Ищем машину', const Color(0xFFD97A00)),
      'accepted' => ('Водитель едет', const Color(0xFF2F7BEA)),
      'arrived' => ('На месте', const Color(0xFF2F7BEA)),
      'riding' => ('В пути', const Color(0xFF6E56CF)),
      'done' => ('Выполнен', AdminC.ok),
      'cancelled' => ('Отменён', context.muted),
      _ => (s, context.muted),
    };

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = orderStatus(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Строка заказа: время, маршрут, цена, клиент, водитель, статус.
class OrderRow extends StatelessWidget {
  final TaxiOrder order;
  final Widget? trailing;
  final bool highlight;
  const OrderRow({super.key, required this.order, this.trailing, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? context.danger.withOpacity(.07) : context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight ? context.danger.withOpacity(.4) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(hm(o.createdAt),
                  style: TextStyle(color: context.muted, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${o.from.isEmpty ? '—' : o.from} → ${o.to.isEmpty ? '—' : o.to}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text('${o.price} ₸',
                  style: TextStyle(color: context.ink, fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(status: o.status),
              if (o.tariff == 'cargo' || o.tariff == 'delivery')
                Text(o.tariff == 'cargo' ? 'Грузовое' : 'Доставка',
                    style: TextStyle(color: context.ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
              if (o.tariff == 'cargo' && o.status == 'searching')
                Text(o.bids.isEmpty
                        ? 'предложений нет'
                        : 'предложений: ${o.bids.length}, от ${o.bids.first.price} ₸',
                    style: TextStyle(color: context.muted, fontSize: 12.5)),
              if (o.comment.isNotEmpty)
                Text('«${o.comment}»', style: TextStyle(color: context.ink2, fontSize: 12.5)),
              if (o.createdBy == 'manager')
                Text('по звонку', style: TextStyle(color: context.muted, fontSize: 12.5)),
              SelectableText(
                [o.clientName, o.clientPhone].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(color: context.muted, fontSize: 12.5),
              ),
              if (o.driverName != null)
                Text('Водитель: ${o.driverName}${o.driverPlate == null ? '' : ' · ${o.driverPlate}'}',
                    style: TextStyle(color: context.ink2, fontSize: 12.5)),
            ],
          ),
          if (trailing != null) ...[const SizedBox(height: 8), trailing!],
        ],
      ),
    );
  }
}
