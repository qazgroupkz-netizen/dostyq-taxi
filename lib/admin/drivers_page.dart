import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/drivers.dart';
import '../state.dart';
import '../theme.dart';

/// Первые 3 месяца после одобрения — бесплатно.
const _freeDays = 90;

String _date(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

class DriversPage extends StatefulWidget {
  const DriversPage({super.key});
  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  // Один поток на всё время страницы: новый поток при каждой перерисовке мигал бы загрузкой.
  late final Stream<List<DriverProfile>> _all = context.read<AppState>().drivers.watchAll();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return StreamBuilder<List<DriverProfile>>(
      stream: _all,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Не удалось загрузить водителей: ${snap.error}'));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final inRegion = snap.data!.where((d) => d.region == state.regionId).toList();
        final pending = inRegion.where((d) => d.approval == Approval.pending).toList();
        final others = inRegion.where((d) => d.approval != Approval.pending).toList();
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Material(
                color: context.paper,
                child: TabBar(
                  labelColor: context.accent,
                  indicatorColor: context.taxi,
                  tabs: [
                    Tab(text: 'Анкеты (${pending.length})'),
                    Tab(text: 'Водители (${others.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _list(context, pending, 'Новых анкет нет'),
                    _list(context, others, 'Водителей пока нет'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context, List<DriverProfile> list, String empty) {
    if (list.isEmpty) {
      return Center(child: Text(empty, style: TextStyle(color: context.muted, fontSize: 15)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _DriverCard(driver: list[i]),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final DriverProfile driver;
  const _DriverCard({required this.driver});

  void _snack(BuildContext context, String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _run(BuildContext context, Future<void> Function() f, String done) async {
    try {
      await f();
      if (context.mounted) _snack(context, done);
    } catch (e) {
      if (context.mounted) _snack(context, 'Ошибка: $e');
    }
  }

  DateTime _from(DateTime? until) {
    final now = DateTime.now();
    return until != null && until.isAfter(now) ? until : now;
  }

  Future<void> _reject(BuildContext context) async {
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;
    await _run(context, () => repo.reject(driver.uid, reason), 'Анкета отклонена');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppState>().drivers;
    final d = driver;
    final days = d.subscriptionDaysLeft;
    final (statusText, statusColor) = switch (d.approval) {
      Approval.pending => ('На проверке', const Color(0xFFD97A00)),
      Approval.approved => d.subscriptionActive
          ? ('Работает', AdminC.ok)
          : ('Подписка закончилась', context.danger),
      Approval.rejected => ('Отклонён', context.danger),
      Approval.blocked => ('Заблокирован', context.danger),
      Approval.none => ('Без анкеты', context.muted),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.lineC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: context.taxiSft,
                child: Text(d.name.isEmpty ? '?' : d.name.characters.first.toUpperCase(),
                    style: TextStyle(color: context.accent, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name.isEmpty ? 'Без имени' : d.name,
                        style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                    SelectableText('${d.vehicle == 'cargo' ? 'Грузовая · ' : ''}${d.phone} · ${d.car} · ${d.plate}',
                        style: TextStyle(color: context.muted, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusText,
                    style: TextStyle(color: statusColor, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (d.ipUntil != null || d.elicenseUntil != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD97A00).withOpacity(.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                [
                  if (d.ipUntil != null) 'без ИП · оформит до ${_date(d.ipUntil)}',
                  if (d.elicenseUntil != null) 'без E-license · до ${_date(d.elicenseUntil)}',
                ].join('   '),
                style: const TextStyle(color: Color(0xFFB36200), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          if (d.approval == Approval.pending)
            Text('Подана: ${_date(d.submittedAt)}', style: TextStyle(color: context.muted, fontSize: 13)),
          if (d.approval == Approval.rejected && d.rejectReason != null)
            Text('Причина: ${d.rejectReason}', style: TextStyle(color: context.muted, fontSize: 13)),
          if (d.approval == Approval.approved || d.approval == Approval.blocked)
            Text(
              'Подписка до ${_date(d.subscriptionUntil)}'
              '${days == null ? '' : days < 0 ? ' · закончилась' : ' · осталось $days дн.'}',
              style: TextStyle(
                color: days != null && days <= 3 ? context.danger : context.muted,
                fontSize: 13, fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _DocsDialog(driver: d),
                ),
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: const Text('Документы'),
              ),
              if (d.approval == Approval.pending || d.approval == Approval.rejected) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: context.taxi),
                  onPressed: () => _run(
                    context,
                    () => repo.approve(d.uid,
                        until: _from(d.subscriptionUntil).add(const Duration(days: _freeDays))),
                    'Одобрен. Подписка бесплатно на 3 месяца.',
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Одобрить'),
                ),
                if (d.approval == Approval.pending)
                  OutlinedButton.icon(
                    onPressed: () => _reject(context),
                    icon: Icon(Icons.close_rounded, size: 18, color: context.danger),
                    label: Text('Отклонить', style: TextStyle(color: context.danger)),
                  ),
              ],
              if (d.approval == Approval.approved) ...[
                OutlinedButton(
                  onPressed: () => _run(
                    context,
                    () => repo.setSubscriptionUntil(
                        d.uid, _from(d.subscriptionUntil).add(const Duration(days: 7))),
                    'Продлено на неделю',
                  ),
                  child: const Text('+ неделя'),
                ),
                OutlinedButton(
                  onPressed: () => _run(
                    context,
                    () => repo.setSubscriptionUntil(
                        d.uid, _from(d.subscriptionUntil).add(const Duration(days: 30))),
                    'Продлено на месяц',
                  ),
                  child: const Text('+ месяц'),
                ),
              ],
              if (d.approval == Approval.approved)
                TextButton.icon(
                  onPressed: () => _run(context, () => repo.setBlocked(d.uid, true), 'Заблокирован'),
                  icon: Icon(Icons.block_rounded, size: 18, color: context.danger),
                  label: Text('Заблокировать', style: TextStyle(color: context.danger)),
                ),
              if (d.approval == Approval.blocked)
                TextButton.icon(
                  onPressed: () => _run(context, () => repo.setBlocked(d.uid, false), 'Разблокирован'),
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Разблокировать'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocsDialog extends StatelessWidget {
  final DriverProfile driver;
  const _DocsDialog({required this.driver});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppState>().drivers;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        child: FutureBuilder<Map<String, Uint8List>>(
          future: repo.loadDocs(driver.uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Не удалось загрузить документы: ${snap.error}'),
              );
            }
            if (!snap.hasData) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final docs = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Документы · ${driver.name}',
                          style: TextStyle(color: context.ink, fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final e in driverDocKinds.entries) ...[
                  Text(e.value,
                      style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (docs[e.key] == null)
                    Text(
                      switch (e.key) {
                        'ip' when driver.ipUntil != null => 'Ещё нет · оформит до ${_date(driver.ipUntil)}',
                        'elicense' when driver.elicenseUntil != null =>
                          'Ещё нет · оформит до ${_date(driver.elicenseUntil)}',
                        _ => 'Не загружено',
                      },
                      style: TextStyle(color: context.danger),
                    )
                  else
                    GestureDetector(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            maxScale: 5,
                            child: Image.memory(docs[e.key]!),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(docs[e.key]!, height: 220, fit: BoxFit.contain),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
