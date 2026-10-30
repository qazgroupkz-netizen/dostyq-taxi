import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'i18n/kk_client.dart';
import 'i18n/kk_driver.dart';
import 'i18n/kk_screens.dart';
import 'i18n/kk_apply.dart';

/// Язык интерфейса: 'ru' (по умолчанию) или 'kk'.
final appLang = ValueNotifier<String>('ru');

const _prefsKey = 'lang';

// Переводы на казахский. Ключ — русский текст ровно как в коде.
// Не const: одинаковые ключи в разных файлах не ломают сборку.
final Map<String, String> _kk = {
  ...kkApply,
  ...kkScreens,
  ...kkDriver,
  ...kkClient,
};

bool get isKk => appLang.value == 'kk';

/// Перевод строки. Нет перевода — русский текст.
String tr(String ru) {
  if (appLang.value != 'kk') return ru;
  return _kk[ru] ?? ru;
}

/// Перевод с подстановкой: trf('Место № {n}', {'n': 2}).
String trf(String ru, Map<String, Object> args) {
  var s = tr(ru);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

Future<void> loadLang() async {
  try {
    final p = await SharedPreferences.getInstance();
    final l = p.getString(_prefsKey);
    if (l == 'kk' || l == 'ru') appLang.value = l!;
  } catch (_) {}
}

Future<void> setLang(String l) async {
  if (appLang.value != l) {
    appLang.value = l;
    _rebuildAll();
  }
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, l);
  } catch (_) {}
}

// const-экраны сами не перестраиваются — помечаем всё дерево.
void _rebuildAll() {
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}

/// Окно выбора языка: «Русский» / «Қазақша».
Future<void> pickLanguage(BuildContext context) async {
  final l = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Тіл / Язык'),
      children: [
        for (final e in const [('ru', 'Русский'), ('kk', 'Қазақша')])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, e.$1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(e.$2, style: const TextStyle(fontSize: 18)),
                  ),
                  if (appLang.value == e.$1) const Icon(Icons.check),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  if (l != null) await setLang(l);
}
