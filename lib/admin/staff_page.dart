import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../data/staff.dart';
import '../data/supabase/sb_staff.dart';
import '../theme.dart';
import 'admin_ui.dart';

const _adminUrl = 'https://alakoltaxi.kz/admin/';

/// Сотрудники: админ добавляет менеджеров по номеру телефона.
class StaffPage extends StatefulWidget {
  const StaffPage({super.key});
  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final StaffRepository? _repo = kUseSupabase ? SupabaseStaffRepository() : null;
  final _phone = TextEditingController();
  final _name = TextEditingController();
  String _role = 'manager';
  bool _busy = false;
  List<StaffMember>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _load() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final list = await repo.list();
      if (mounted) {
        setState(() {
          _list = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  static String _fmt(String p) => p.length == 10
      ? '+7 ${p.substring(0, 3)} ${p.substring(3, 6)} ${p.substring(6, 8)} ${p.substring(8)}'
      : p;

  static String _roleName(String r) => r == 'admin' ? 'админ' : 'менеджер';

  String _invite(StaffMember m) =>
      'Здравствуйте${m.name.isEmpty ? '' : ', ${m.name}'}! Вас добавили в $kBrand как ${_roleName(m.role)}а. '
      'Откройте $_adminUrl на компьютере или телефоне и войдите по своему номеру ${_fmt(m.phone)} — '
      'придёт код. Сохраните ссылку в закладки.';

  Future<void> _copy(StaffMember m) async {
    await Clipboard.setData(ClipboardData(text: _invite(m)));
    _snack('Приглашение скопировано — отправьте его в WhatsApp');
  }

  String _errText(Object e) {
    final s = '$e';
    if (s.contains('bad-phone')) return 'Номер должен быть из 10 цифр после +7';
    if (s.contains('self')) return 'Свой номер менять нельзя';
    if (s.contains('forbidden')) return 'Добавлять сотрудников может только админ';
    return 'Не получилось: $s';
  }

  Future<void> _add() async {
    final repo = _repo;
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final key = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    if (repo == null) return;
    if (key.length != 10) {
      _snack('Введите номер: 10 цифр после +7');
      return;
    }
    setState(() => _busy = true);
    try {
      await repo.set(key, _role, name: _name.text.trim());
      final m = StaffMember(phone: key, role: _role, name: _name.text.trim(), joined: false);
      _phone.clear();
      _name.clear();
      await _load();
      if (mounted) await _copy(m);
    } catch (e) {
      _snack(_errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(StaffMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Убрать доступ?'),
        content: Text('${m.name.isEmpty ? _fmt(m.phone) : m.name} больше не сможет входить в админку.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminC.bad, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Убрать'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo?.set(m.phone, 'client');
      await _load();
    } catch (e) {
      _snack(_errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, {String? prefix}) => InputDecoration(
          labelText: label,
          prefixText: prefix,
          isDense: true,
          filled: true,
          fillColor: context.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        );
    final wide = MediaQuery.of(context).size.width >= 900;

    final form = AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Добавить сотрудника',
              style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]'))],
            decoration: deco('Номер телефона', prefix: '+7 '),
          ),
          const SizedBox(height: 10),
          TextField(controller: _name, decoration: deco('Имя, например: Айгерим')),
          const SizedBox(height: 12),
          FilterChips<String>(
            items: const {'manager': 'Менеджер', 'admin': 'Админ'},
            value: _role,
            onChanged: (v) => setState(() => _role = v),
          ),
          const SizedBox(height: 10),
          Text(
            _role == 'manager'
                ? 'Менеджер видит только своё окно: Диспетчерская, Заказы и Межгород. '
                    'Принимает заказы по звонку и следит за ними. Цены, финансы, водителей и настройки он не видит.'
                : 'Админ видит и меняет всё: цены, финансы, водителей, сотрудников.',
            style: TextStyle(color: context.muted, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _busy ? null : _add,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_busy ? 'Добавляем…' : 'Добавить и скопировать приглашение'),
          ),
        ],
      ),
    );

    final list = _list;
    final people = AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Кто имеет доступ',
              style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_repo == null)
            Text('Работает только с новой базой.', style: TextStyle(color: context.muted))
          else if (_error != null)
            Text('Не удалось загрузить: $_error', style: const TextStyle(color: AdminC.bad))
          else if (list == null)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
          else if (list.isEmpty)
            Text('Пока никого.', style: TextStyle(color: context.muted))
          else
            for (final m in list)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.lineC))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name.isEmpty ? 'Без имени' : m.name,
                              style: TextStyle(color: context.ink, fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(_fmt(m.phone), style: TextStyle(color: context.muted, fontSize: 13.5)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            StatusPill(m.role == 'admin' ? 'Админ' : 'Менеджер',
                                m.role == 'admin' ? PillTone.violet : PillTone.info),
                            StatusPill(m.joined ? 'Входил' : 'Ещё не входил',
                                m.joined ? PillTone.ok : PillTone.warn),
                          ]),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Скопировать приглашение',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () => _copy(m),
                    ),
                    IconButton(
                      tooltip: 'Убрать доступ',
                      icon: const Icon(Icons.person_remove_outlined, color: AdminC.bad),
                      onPressed: () => _remove(m),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );

    return ListView(
      padding: EdgeInsets.all(wide ? 28 : 12),
      children: [
        const AdminHead(
          title: 'Сотрудники',
          sub: 'Добавьте номер — человек войдёт по ссылке $_adminUrl со своим номером',
        ),
        const SizedBox(height: 18),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 420, child: form),
              const SizedBox(width: 16),
              Expanded(child: people),
            ],
          )
        else ...[
          form,
          const SizedBox(height: 12),
          people,
        ],
      ],
    );
  }
}
