import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/ornament_icon.dart';
import '../services/phone_auth.dart' as phone_web;

class AuthScreen extends StatefulWidget {
  final bool nameOnly;
  const AuthScreen({super.key, this.nameOnly = false});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();

  bool _codeSent  = false;
  late bool _nameStep = widget.nameOnly;
  bool _loading   = false;
  String? _error;

  String? _verificationId;
  ConfirmationResult? _webResult;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _fullPhone =>
      '+7${_phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '')}';

  Future<void> _sendCode() async {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) {
      setState(() => _error = tr('Введите номер телефона (10 цифр)'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (kIsWeb) {
        _webResult = await phone_web.signInWithPhone(_fullPhone);
        if (mounted) setState(() { _codeSent = true; _loading = false; });
      } else {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: _fullPhone,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (cred) async {
            final uc = await FirebaseAuth.instance.signInWithCredential(cred);
            await _afterLogin(uc.user);
          },
          verificationFailed: (e) {
            if (mounted) setState(() {
              _error = _errMsg(e.code);
              _loading = false;
            });
          },
          codeSent: (vid, _) {
            _verificationId = vid;
            if (mounted) setState(() { _codeSent = true; _loading = false; });
          },
          codeAutoRetrievalTimeout: (_) {},
        );
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _verifyCode() async {
    if (_codeCtrl.text.trim().length < 6) {
      setState(() => _error = tr('Введите 6-значный код'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      UserCredential uc;
      if (kIsWeb) {
        uc = await _webResult!.confirm(_codeCtrl.text.trim());
      } else {
        final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _codeCtrl.text.trim(),
        );
        uc = await FirebaseAuth.instance.signInWithCredential(cred);
      }
      await _afterLogin(uc.user);
    } catch (_) {
      if (mounted) setState(() {
        _error = tr('Неверный код. Попробуйте ещё раз.');
        _loading = false;
      });
    }
  }

  Future<void> _afterLogin(User? user) async {
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    if (!snap.exists) {
      if (mounted) setState(() { _nameStep = true; _loading = false; });
    }
  }

  Future<void> _saveName() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = tr('Введите ваше имя'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameCtrl.text.trim(),
        'phone': user.phoneNumber ?? _fullPhone,
        'role': 'client',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) setState(() { _error = trf('Не удалось сохранить: {e}', {'e': e}); _loading = false; });
      return;
    }
    if (mounted) await context.read<AppState>().reloadProfile();
  }

  String _errMsg(String code) {
    switch (code) {
      case 'invalid-phone-number':       return tr('Неверный формат номера');
      case 'too-many-requests':          return tr('Слишком много попыток. Попробуйте позже.');
      case 'invalid-verification-code':  return tr('Неверный код');
      default:                           return trf('Ошибка ({code})', {'code': code});
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, top + 44, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: context.taxi,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: OrnamentIcon(size: 34, color: context.onTaxi),
              ),
              const Spacer(),
              // Переключатель языка (подписи не переводятся).
              TextButton(
                onPressed: () async {
                  await setLang(appLang.value == 'kk' ? 'ru' : 'kk');
                  if (mounted) setState(() => _error = null);
                },
                child: Text(appLang.value == 'kk' ? 'Русский' : 'Қазақша',
                    style: TextStyle(
                        color: context.accent,
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 22),
            Text(kBrand,
                style: TextStyle(
                  color: context.accent,
                  fontSize: 13, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                )),
            const SizedBox(height: 8),
            Text(
              _nameStep ? tr('Как вас зовут?') :
              _codeSent ? tr('Введите код') : tr('Вход'),
              style: TextStyle(
                color: context.ink,
                fontSize: 32, fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _nameStep
                  ? tr('Имя увидит водитель при заказе')
                  : _codeSent
                      ? trf('Код отправлен на {phone}', {'phone': _fullPhone})
                      : tr('Такси и доставка по посёлку Достык'),
              style: TextStyle(color: context.muted, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 36),

            if (_nameStep)
              _buildNameField(context)
            else if (!_codeSent)
              _buildPhoneField(context)
            else
              _buildCodeField(context),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.error_outline_rounded,
                    color: context.danger, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(_error!,
                    style: TextStyle(color: context.danger, fontSize: 14))),
              ]),
            ],

            const SizedBox(height: 24),
            _buildCta(context),

            if (_codeSent && !_nameStep) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _codeSent = false; _codeCtrl.clear(); _error = null;
                  }),
                  child: Text(tr('Изменить номер'),
                      style: TextStyle(color: context.muted, fontSize: 14)),
                ),
              ),
            ],

            const SizedBox(height: 36),
            Text(
              tr('Продолжая, вы соглашаетесь с пользовательским соглашением '
                  'и даёте согласие на обработку персональных данных.'),
              style: TextStyle(color: context.muted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.lineC),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: context.lineC)),
          ),
          child: Text('+7',
              style: TextStyle(
                color: context.ink, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            style: TextStyle(
                color: context.ink, fontSize: 18, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: '700 000 00 00',
              hintStyle: TextStyle(color: context.hint),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            onSubmitted: (_) => _sendCode(),
          ),
        ),
      ]),
    );
  }

  Widget _buildCodeField(BuildContext context) {
    return TextField(
      controller: _codeCtrl,
      keyboardType: TextInputType.number,
      maxLength: 6,
      autofocus: true,
      style: TextStyle(
        color: context.ink,
        fontSize: 30, fontWeight: FontWeight.w700,
        letterSpacing: 10,
      ),
      decoration: InputDecoration(
        hintText: '••••••',
        hintStyle: TextStyle(color: context.hint, letterSpacing: 8, fontSize: 24),
        counterText: '',
        filled: true,
        fillColor: context.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: context.lineC),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: context.taxi, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: context.lineC),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      ),
      onSubmitted: (_) => _verifyCode(),
    );
  }

  Widget _buildNameField(BuildContext context) {
    return TextField(
      controller: _nameCtrl,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      autofocus: true,
      style: TextStyle(
          color: context.ink, fontSize: 18, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: tr('Например: Айгерим'),
        hintStyle: TextStyle(color: context.hint),
        filled: true,
        fillColor: context.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: context.lineC),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: context.taxi, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: context.lineC),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      onSubmitted: (_) => _saveName(),
    );
  }

  Widget _buildCta(BuildContext context) {
    final label = _nameStep ? tr('Продолжить') : _codeSent ? tr('Войти') : tr('Получить код');
    final action = _nameStep ? _saveName : _codeSent ? _verifyCode : _sendCode;
    return GestureDetector(
      onTap: _loading ? null : action,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: context.taxi,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: context.taxi.withOpacity(.4),
              blurRadius: 24, offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: _loading
            ? SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: context.onTaxi, strokeWidth: 2.5))
            : Text(label,
                style: TextStyle(
                  color: context.onTaxi,
                  fontSize: 17, fontWeight: FontWeight.w700,
                )),
      ),
    );
  }
}
