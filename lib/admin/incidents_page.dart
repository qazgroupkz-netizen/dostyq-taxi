import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/incidents.dart';
import '../services/open_link.dart';
import '../state.dart';
import '../theme.dart';
import 'admin_ui.dart';
import 'order_ui.dart';

/// SOS и жалобы — как в reference/admin-prototype.html: сначала срочное, решённые внизу.
class IncidentsPage extends StatefulWidget {
  const IncidentsPage({super.key});
  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  Stream<List<Incident>>? _stream;
  String? _region;

  static int _rank(Incident i) => i.resolved ? 3 : i.kind == 'sos' ? 0 : i.kind == 'complaint' ? 1 : 2;

  static String _ago(DateTime? t) {
    if (t == null) return '—';
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return 'только что';
    if (m < 60) return '$m мин назад';
    return dayTime(t);
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_region != state.regionId) {
      _region = state.regionId;
      _stream = state.incidents.watchRegion(state.regionId);
    }
    final wide = MediaQuery.of(context).size.width >= 900;
    return StreamBuilder<List<Incident>>(
      stream: _stream,
      builder: (context, snap) {
        final list = [...?snap.data]..sort((a, b) {
            final r = _rank(a).compareTo(_rank(b));
            return r != 0 ? r : (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
          });
        return ListView(
          padding: EdgeInsets.all(wide ? 28 : 12),
          children: [
            const AdminHead(title: 'SOS и жалобы', sub: 'Сначала срочное. Решённые уходят вниз.'),
            const SizedBox(height: 18),
            if (snap.hasError)
              AdminCard(child: Text('Не удалось загрузить: ${snap.error}', style: const TextStyle(color: AdminC.bad)))
            else if (!snap.hasData)
              const Center(child: CircularProgressIndicator())
            else if (list.isEmpty)
              AdminCard(
                child: Text('Пока тихо: SOS и жалоб нет.', style: TextStyle(color: context.muted, fontSize: 15)),
              )
            else
              for (final i in list)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: _card(context, state, i, wide)),
          ],
        );
      },
    );
  }

  Widget _icon(Incident i) {
    final (bg, child) = switch (i.kind) {
      'sos' => (
          AdminC.bad,
          const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      'complaint' => (
          const Color(0xFFFFF1DE),
          const Icon(Icons.error_outline_rounded, color: AdminC.warn, size: 22),
        ),
      _ => (
          const Color(0xFFE8F0FE),
          const Icon(Icons.chat_bubble_outline_rounded, color: AdminC.info, size: 20),
        ),
    };
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }

  Widget _card(BuildContext context, AppState state, Incident i, bool wide) {
    final meta = [
      _ago(i.createdAt),
      if (i.orderId != null && i.orderId!.length > 4)
        'заказ #${i.orderId!.substring(i.orderId!.length - 4).toUpperCase()}',
      [i.authorName, i.authorPhone].where((s) => s.isNotEmpty).join(' '),
    ].where((s) => s.isNotEmpty).join(' · ');

    final buttons = i.resolved
        ? const StatusPill('Решено', PillTone.ok)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i.authorPhone.isNotEmpty)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminC.surface,
                    foregroundColor: AdminC.ink,
                    minimumSize: const Size(0, 38),
                  ),
                  onPressed: () {
                    if (!openLink('tel:${i.authorPhone}')) _snack('Номер: ${i.authorPhone}');
                  },
                  child: const Text('Позвонить', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 6),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AdminC.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 38),
                ),
                onPressed: () async {
                  try {
                    await state.incidents.resolve(i.id);
                  } catch (e) {
                    _snack('Не получилось: $e');
                  }
                },
                child: const Text('Решено', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(i.title,
            style: TextStyle(
              color: i.resolved ? context.muted : AdminC.ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            )),
        if (i.body.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(i.body,
              style: TextStyle(color: i.resolved ? context.muted : AdminC.ink, fontSize: 14, height: 1.4)),
        ],
        const SizedBox(height: 6),
        Text(meta, style: TextStyle(color: context.muted, fontSize: 12.5)),
      ],
    );

    return Opacity(
      opacity: i.resolved ? .7 : 1,
      child: AdminCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _icon(i),
            const SizedBox(width: 14),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(child: text), const SizedBox(width: 12), buttons],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [text, const SizedBox(height: 10), buttons],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
