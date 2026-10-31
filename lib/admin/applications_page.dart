import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/drivers.dart';
import '../state.dart';
import '../theme.dart';
import 'admin_ui.dart';

/// Первые 3 месяца после одобрения — бесплатно.
const _freeDays = 90;

/// Что проверяем в анкете: плитка → какие фото к ней относятся.
const _checks = <String, List<String>>{
  'Права, 2 стороны': ['license_front', 'license_back'],
  'Техпаспорт, 2 стороны': ['techpass_front', 'techpass_back'],
  'Фото машины': ['car'],
};

/// Проверка анкет — как в reference/admin-prototype.html: карточки с документами.
class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});
  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  late final Stream<List<DriverProfile>> _all = context.read<AppState>().drivers.watchAll();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= 900;
    return StreamBuilder<List<DriverProfile>>(
      stream: _all,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Не удалось загрузить анкеты: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!
            .where((d) => d.region == state.regionId && d.approval == Approval.pending)
            .toList()
          ..sort((a, b) => (a.submittedAt ?? DateTime(0)).compareTo(b.submittedAt ?? DateTime(0)));
        return ListView(
          padding: EdgeInsets.all(wide ? 28 : 12),
          children: [
            const AdminHead(
              title: 'Проверка анкет',
              sub: 'Новые водители ждут одобрения. Проверьте документы и машину.',
            ),
            const SizedBox(height: 18),
            if (list.isEmpty)
              AdminCard(
                child: Text('Новых анкет нет', style: TextStyle(color: context.muted, fontSize: 15)),
              )
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final d in list)
                    SizedBox(width: wide ? 400 : double.infinity, child: _AppCard(key: ValueKey(d.uid), driver: d)),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _AppCard extends StatefulWidget {
  final DriverProfile driver;
  const _AppCard({super.key, required this.driver});
  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  late final Future<Map<String, Uint8List>> _docs =
      context.read<AppState>().drivers.loadDocs(widget.driver.uid);
  bool _busy = false;

  static const _avatarColors = [
    [Color(0xFF5B8DEF), Color(0xFF3F67D8)],
    [Color(0xFFF5A742), Color(0xFFE5862A)],
    [Color(0xFF34C38F), Color(0xFF1E9E6F)],
    [Color(0xFFA27CF0), Color(0xFF7E57D6)],
  ];

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _run(Future<void> Function() f, String done) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) _snack(done);
    } catch (e) {
      if (mounted) _snack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final repo = context.read<AppState>().drivers;
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отклонить анкету'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Причина, её увидит водитель',
            hintText: 'Например: не видно номер на фото прав',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Отклонить')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    await _run(() => repo.reject(widget.driver.uid, reason), 'Анкета отклонена');
  }

  void _approve() {
    final repo = context.read<AppState>().drivers;
    final d = widget.driver;
    final now = DateTime.now();
    final from = d.subscriptionUntil != null && d.subscriptionUntil!.isAfter(now) ? d.subscriptionUntil! : now;
    _run(() => repo.approve(d.uid, until: from.add(const Duration(days: _freeDays))),
        'Одобрен. Подписка бесплатно на 3 месяца.');
  }

  void _show(String title, List<Uint8List> photos) => showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
            child: ListView(
              padding: const EdgeInsets.all(16),
              shrinkWrap: true,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('$title · ${widget.driver.name}',
                        style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ]),
                for (final p in photos)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(p)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _tile(String label, List<Uint8List?> photos) {
    final have = photos.whereType<Uint8List>().toList();
    final full = have.length == photos.length;
    return Material(
      color: AdminC.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: have.isEmpty ? null : () => _show(label, have),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 32,
                  child: have.isEmpty
                      ? const ColoredBox(color: Color(0xFFE2E4E8))
                      : Image.memory(have.first, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: AdminC.ink, fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              full
                  ? const Icon(Icons.check_rounded, color: AdminC.ok, size: 20)
                  : const Text('?', style: TextStyle(color: AdminC.warn, fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    final colors = _avatarColors[d.uid.hashCode.abs() % _avatarColors.length];
    final carOk = d.carModel.isNotEmpty && d.plate.isNotEmpty;
    final sub = [
      d.vehicle == 'cargo' ? 'Грузовая машина' : 'Легковая машина',
      if (d.submittedAt != null)
        'анкета от ${d.submittedAt!.day.toString().padLeft(2, '0')}.${d.submittedAt!.month.toString().padLeft(2, '0')}',
    ].join(' · ');

    return AdminCard(
      child: FutureBuilder<Map<String, Uint8List>>(
        future: _docs,
        builder: (context, snap) {
          final docs = snap.data ?? const <String, Uint8List>{};
          final loading = !snap.hasData && !snap.hasError;
          final complete = carOk && _checks.values.every((kinds) => kinds.every((k) => docs[k] != null));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                    ),
                    child: Text(d.name.isEmpty ? '?' : d.name.characters.first.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name.isEmpty ? 'Без имени' : d.name,
                            style: const TextStyle(color: AdminC.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                        SelectableText(d.phone, style: TextStyle(color: context.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.directions_car_outlined, size: 18, color: AdminC.ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [d.car, d.plate].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(color: AdminC.ink, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(color: context.muted, fontSize: 13)),
              const SizedBox(height: 12),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.9,
                  children: [
                    for (final e in _checks.entries) _tile(e.key, [for (final k in e.value) docs[k]]),
                    _infoTile('Марка и номер', carOk),
                  ],
                ),
              if (!loading && !complete) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill('Не хватает документа', PillTone.warn),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _reject,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFDEBEC),
                        foregroundColor: AdminC.bad,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Отклонить', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy || !complete ? null : _approve,
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminC.yellow,
                        foregroundColor: AdminC.ink,
                        disabledBackgroundColor: const Color(0xFFFFEAA0),
                        disabledForegroundColor: const Color(0xFF8A8F98),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Одобрить', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoTile(String label, bool ok) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AdminC.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 32,
              decoration: BoxDecoration(color: const Color(0xFFE2E4E8), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.pin_outlined, size: 18, color: AdminC.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: AdminC.ink, fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
            ok
                ? const Icon(Icons.check_rounded, color: AdminC.ok, size: 20)
                : const Text('?', style: TextStyle(color: AdminC.warn, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      );
}
