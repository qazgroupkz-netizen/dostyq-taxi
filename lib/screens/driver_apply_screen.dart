import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../data/drivers.dart';
import '../state.dart';
import '../theme.dart';

/// Анкета водителя: статус проверки и форма с документами.
class DriverApplyScreen extends StatefulWidget {
  const DriverApplyScreen({super.key});
  @override
  State<DriverApplyScreen> createState() => _DriverApplyScreenState();
}

class _DriverApplyScreenState extends State<DriverApplyScreen> {
  final _name = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  final _photos = <String, Uint8List>{};
  final _uploading = <String>{};
  bool _consent = false;
  bool _offer = false;
  bool _sending = false;
  bool _editing = false;
  bool _filled = false;
  bool _left = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      final uid = state.uid;
      if (uid == null) return;
      try {
        final docs = await state.drivers.loadDocs(uid);
        if (mounted) setState(() => _photos.addAll(docs));
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _model.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  void _fillFrom(DriverProfile? p, String fallbackName) {
    if (_filled) return;
    _filled = true;
    _name.text = (p?.name.isNotEmpty ?? false) ? p!.name : fallbackName;
    _model.text = p?.carModel ?? '';
    _color.text = p?.carColor ?? '';
    _plate.text = p?.plate ?? '';
  }

  Future<void> _pick(String kind) async {
    final state = context.read<AppState>();
    final uid = state.uid;
    if (uid == null) return;
    // Сжимаем на устройстве: в базе одна запись — не больше 1 МБ.
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200, maxHeight: 1200, imageQuality: 60,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 700 * 1024) {
      setState(() => _error = 'Фото слишком большое. Сделайте снимок поменьше или обрежьте его.');
      return;
    }
    setState(() {
      _uploading.add(kind);
      _error = null;
    });
    try {
      await state.drivers.saveDoc(uid, kind, bytes);
      if (mounted) setState(() => _photos[kind] = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = 'Не удалось загрузить фото: $e');
    } finally {
      if (mounted) setState(() => _uploading.remove(kind));
    }
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final uid = state.uid;
    if (uid == null) return;
    final missing = driverDocKinds.keys.where((k) => !_photos.containsKey(k)).toList();
    if (_name.text.trim().isEmpty ||
        _model.text.trim().isEmpty ||
        _color.text.trim().isEmpty ||
        _plate.text.trim().isEmpty) {
      setState(() => _error = 'Заполните имя, марку, цвет и госномер машины');
      return;
    }
    if (missing.isNotEmpty) {
      setState(() => _error = 'Добавьте фото: ${missing.map((k) => driverDocKinds[k]).join(', ')}');
      return;
    }
    if (!_consent || !_offer) {
      setState(() => _error = 'Нужно согласие на обработку данных и принятие оферты');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await state.drivers.submit(
        uid: uid,
        name: _name.text.trim(),
        phone: FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
        carModel: _model.text.trim(),
        carColor: _color.text.trim(),
        plate: _plate.text.trim().toUpperCase(),
        region: state.regionId,
      );
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) setState(() => _error = 'Не удалось отправить: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.myDriver;
    final approval = p?.approval ?? Approval.none;
    _fillFrom(p, state.userName);

    // Одобрили, пока экран открыт, — сразу в режим водителя.
    if (approval == Approval.approved && !_left) {
      _left = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
        state.setDriverMode(true);
      });
    }

    final showForm = _editing ||
        approval == Approval.none ||
        approval == Approval.rejected;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        title: const Text('Стать водителем'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (approval == Approval.pending && !_editing)
            _StatusCard(
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFD97A00),
              title: 'Анкета на проверке',
              text: 'Админ проверит документы и машину. Обычно это занимает до одного дня. '
                  'Когда одобрят, здесь откроется режим водителя.',
              action: TextButton(
                onPressed: () => setState(() => _editing = true),
                child: const Text('Изменить анкету'),
              ),
            ),
          if (approval == Approval.rejected)
            _StatusCard(
              icon: Icons.error_outline_rounded,
              color: context.danger,
              title: 'Анкета отклонена',
              text: 'Причина: ${p?.rejectReason ?? 'не указана'}. Исправьте и отправьте снова.',
            ),
          if (approval == Approval.blocked)
            _StatusCard(
              icon: Icons.block_rounded,
              color: context.danger,
              title: 'Аккаунт водителя заблокирован',
              text: 'Свяжитесь с поддержкой DOSTYQ TAXI.',
            ),
          if (showForm) ...[
            Text('Подключение к DOSTYQ TAXI',
                style: TextStyle(color: context.ink, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Нужны: ИП или платформенная занятость, уведомление о деятельности такси '
              'на E-license, права, техпаспорт и фото машины. '
              'Первые 3 месяца подписка бесплатная.',
              style: TextStyle(color: context.muted, fontSize: 14.5, height: 1.45),
            ),
            const SizedBox(height: 18),
            _field(context, _name, 'Имя и фамилия'),
            _field(context, _model, 'Марка и модель, например: Toyota Camry'),
            _field(context, _color, 'Цвет, например: белая'),
            _field(context, _plate, 'Госномер, например: 045 AKZ 18'),
            const SizedBox(height: 8),
            Text('ДОКУМЕНТЫ',
                style: TextStyle(
                  color: context.taxi, fontSize: 12, fontWeight: FontWeight.w700,
                  letterSpacing: .08 * 12,
                )),
            const SizedBox(height: 8),
            for (final e in driverDocKinds.entries)
              _DocTile(
                title: e.value,
                bytes: _photos[e.key],
                busy: _uploading.contains(e.key),
                onTap: () => _pick(e.key),
              ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text('Согласен на сбор и обработку персональных данных'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _offer,
              onChanged: (v) => setState(() => _offer = v ?? false),
              title: const Text('Принимаю условия публичной оферты для водителей'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: TextStyle(color: context.danger, fontSize: 14)),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _sending || _uploading.isNotEmpty ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: context.taxi,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(_sending ? 'Отправляем…' : 'Отправить на проверку',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(BuildContext context, TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: context.ink, fontSize: 16),
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: context.paper,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.lineC),
            ),
          ),
        ),
      );
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, text;
  final Widget? action;
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: context.ink2, fontSize: 14.5, height: 1.45)),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final String title;
  final Uint8List? bytes;
  final bool busy;
  final VoidCallback onTap;
  const _DocTile({required this.title, required this.bytes, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final has = bytes != null;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: has ? context.jLine : context.lineC),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 64, height: 48,
                color: context.surface,
                child: busy
                    ? const Center(child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                    : has
                        ? Image.memory(bytes!, fit: BoxFit.cover)
                        : Icon(Icons.add_a_photo_outlined, color: context.muted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(has ? 'Загружено · нажмите, чтобы заменить' : 'Нажмите, чтобы добавить фото',
                      style: TextStyle(
                        color: has ? context.taxi : context.muted, fontSize: 12.5,
                      )),
                ],
              ),
            ),
            Icon(has ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: has ? context.taxi : context.muted),
          ],
        ),
      ),
    );
  }
}
