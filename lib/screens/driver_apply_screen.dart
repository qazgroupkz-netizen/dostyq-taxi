import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../data/drivers.dart';
import '../config.dart';
import '../i18n.dart';
import '../legal.dart';
import '../state.dart';
import '../theme.dart';

/// Анкета водителя по шагам: документы → машина.
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

  int _step = 0;
  String _vehicle = 'car';
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
    _vehicle = p?.vehicle ?? 'car';
  }

  Future<void> _pick(String kind) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr('Сфотографировать')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('Выбрать из галереи')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final state = context.read<AppState>();
    final uid = state.uid;
    if (uid == null) return;
    // Сжимаем на устройстве: в базе одна запись — не больше 1 МБ.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200, maxHeight: 1200, imageQuality: 60,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 700 * 1024) {
      setState(() => _error = tr('Фото слишком большое. Сделайте снимок поменьше или обрежьте его.'));
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
      if (mounted) setState(() => _error = trf('Не удалось загрузить фото: {e}', {'e': e}));
    } finally {
      if (mounted) setState(() => _uploading.remove(kind));
    }
  }

  bool get _docsDone => const ['license_front', 'license_back', 'techpass_front', 'techpass_back']
      .every(_photos.containsKey);

  bool get _carDone =>
      _name.text.trim().isNotEmpty &&
      _model.text.trim().isNotEmpty &&
      _color.text.trim().isNotEmpty &&
      _plate.text.trim().isNotEmpty &&
      _photos.containsKey('car');

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final uid = state.uid;
    if (uid == null) return;
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
        vehicle: _vehicle,
      );
      if (mounted) {
        setState(() {
          _editing = false;
          _step = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trf('Не удалось отправить: {e}', {'e': e}));
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

    final showForm = _editing || approval == Approval.none || approval == Approval.rejected;

    final (Widget body, String cta, bool ready, VoidCallback next) = switch (_step) {
      0 => (_docsStep(context), tr('Продолжить'), _docsDone, () => setState(() => _step = 1)),
      _ => (_carStep(context), _sending ? tr('Отправляем…') : tr('Отправить на проверку'),
          _carDone && _consent && _offer && !_sending, _submit),
    };

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  if (showForm && _step > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => setState(() => _step--),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.person_rounded, size: 18),
                    label: Text(tr('Перейти в режим пассажира')),
                    style: TextButton.styleFrom(
                      foregroundColor: context.ink,
                      backgroundColor: context.surface,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (approval == Approval.pending && !_editing)
                    _StatusCard(
                      icon: Icons.hourglass_top_rounded,
                      color: const Color(0xFFD97A00),
                      title: tr('Анкета на проверке'),
                      text: tr('Админ проверит документы и машину. Обычно это занимает до одного дня. '
                          'Когда одобрят, здесь откроется режим водителя.'),
                      action: TextButton(
                        onPressed: () => setState(() {
                          _editing = true;
                          _step = 0;
                        }),
                        child: Text(tr('Изменить анкету')),
                      ),
                    ),
                  if (approval == Approval.rejected)
                    _StatusCard(
                      icon: Icons.error_outline_rounded,
                      color: context.danger,
                      title: tr('Анкета отклонена'),
                      text: trf('Причина: {r}. Исправьте и отправьте снова.',
                          {'r': p?.rejectReason ?? tr('не указана')}),
                    ),
                  if (approval == Approval.blocked)
                    _StatusCard(
                      icon: Icons.block_rounded,
                      color: context.danger,
                      title: tr('Аккаунт водителя заблокирован'),
                      text: trf('Свяжитесь с поддержкой {brand}.', {'brand': kBrand}),
                    ),
                  if (showForm) body,
                  if (showForm && _error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: TextStyle(color: context.danger, fontSize: 14)),
                    ),
                ],
              ),
            ),
            if (showForm)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    onPressed: ready && _uploading.isEmpty ? next : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.taxi,
                      disabledBackgroundColor: context.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(cta, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                color: context.ink, fontSize: 30, fontWeight: FontWeight.w800,
                letterSpacing: -.5, height: 1.15,
              )),
          const SizedBox(height: 8),
          Text(sub,
              style: TextStyle(
                color: context.muted, fontSize: 17, fontWeight: FontWeight.w600, height: 1.35,
              )),
        ],
      );

  Widget _counter(BuildContext context, int done, int total) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trf('{done} из {total} фото', {'done': done, 'total': total}),
                style: TextStyle(color: context.muted, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 4,
                backgroundColor: context.surface,
                color: context.taxi,
              ),
            ),
          ],
        ),
      );

  Widget _pair(BuildContext context, String title, String front, String back) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _tile(context, front, tr('Лицевая сторона'))),
              const SizedBox(width: 14),
              Expanded(child: _tile(context, back, tr('Оборотная сторона'))),
            ],
          ),
          const SizedBox(height: 20),
        ],
      );

  Widget _tile(BuildContext context, String kind, String label) {
    final bytes = _photos[kind];
    final busy = _uploading.contains(kind);
    return GestureDetector(
      onTap: busy ? null : () => _pick(kind),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.6,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: busy
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                    : bytes != null
                        ? Image.memory(bytes, fit: BoxFit.cover, width: double.infinity)
                        : CustomPaint(
                            painter: _DashedRect(color: context.muted),
                            child: Center(
                              child: Icon(Icons.photo_camera_rounded, color: context.ink, size: 30),
                            ),
                          ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(bytes != null ? tr('Готово · заменить') : tr('Сфотографировать'),
              style: TextStyle(
                color: bytes != null ? context.accent : context.muted,
                fontSize: 14.5, fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  Widget _docsStep(BuildContext context) {
    const kinds = ['license_front', 'license_back', 'techpass_front', 'techpass_back'];
    final done = kinds.where(_photos.containsKey).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context, tr('Сфотографируйте документы'),
            tr('Снимите водительское удостоверение и свидетельство о регистрации ТС '
            '(техпаспорт) с обеих сторон. Админ проверит их.')),
        _counter(context, done, kinds.length),
        _pair(context, tr('Водительское удостоверение'), 'license_front', 'license_back'),
        _pair(context, tr('Свидетельство о регистрации (техпаспорт)'), 'techpass_front', 'techpass_back'),
      ],
    );
  }

  Widget _input(BuildContext context, TextEditingController c, String label,
          {TextCapitalization caps = TextCapitalization.sentences}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          textCapitalization: caps,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: context.ink, fontSize: 17),
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: context.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  Widget _carStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context, tr('Машина'), tr('Эти данные увидит клиент, когда вы примете заказ.')),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'car', label: Text(tr('Легковая')), icon: const Icon(Icons.local_taxi_rounded)),
              ButtonSegment(value: 'cargo', label: Text(tr('Грузовая')), icon: const Icon(Icons.local_shipping_rounded)),
            ],
            selected: {_vehicle},
            onSelectionChanged: (s) => setState(() => _vehicle = s.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Text(
            _vehicle == 'cargo'
                ? tr('Вам будут приходить только грузовые заказы: переезды, стройматериалы, мебель.')
                : tr('Вам будут приходить поездки по посёлку и доставка.'),
            style: TextStyle(color: context.muted, fontSize: 13.5, height: 1.4),
          ),
        ),
        _input(context, _name, tr('Имя и фамилия'), caps: TextCapitalization.words),
        _input(context, _model, tr('Марка и модель, например: Toyota Camry')),
        _input(context, _color, tr('Цвет, например: белая')),
        _input(context, _plate, tr('Госномер, например: 045 AKZ 18'),
            caps: TextCapitalization.characters),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: _tile(context, 'car', tr('Фото машины спереди')),
        ),
        const SizedBox(height: 16),
        Text(tr('Первые 3 месяца подписка бесплатная.'),
            style: TextStyle(color: context.muted, fontSize: 14)),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _consent,
          onChanged: (v) => setState(() => _consent = v ?? false),
          title: Text(tr('Согласен на сбор и обработку персональных данных')),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _offer,
          onChanged: (v) => setState(() => _offer = v ?? false),
          title: Text(tr('Принимаю условия публичной оферты для водителей')),
        ),
        const Wrap(spacing: 16, children: [
          LegalLink(LegalDoc.driverOffer, fontSize: 14),
          LegalLink(LegalDoc.privacy, fontSize: 14),
        ]),
      ],
    );
  }

}

class _DashedRect extends CustomPainter {
  final Color color;
  _DashedRect({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 7), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRect old) => old.color != color;
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
