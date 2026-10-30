import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class Place {
  final String id;
  final String name;
  final String sub;
  final IconData icon;
  final Color color;
  final LatLng point;
  final List<String> synonyms;
  final bool chip;

  /// Места одной группы (например, все школы) — одна кнопка-чип со списком.
  final String? group;

  /// Координаты примерные: в OpenStreetMap этого места нет, нужно уточнить на месте.
  final bool approx;

  const Place({
    required this.id,
    required this.name,
    required this.sub,
    required this.icon,
    required this.color,
    required this.point,
    this.synonyms = const [],
    this.chip = false,
    this.group,
    this.approx = false,
  });
}

const placeGroups = {'school': 'Школа'};

// Координаты взяты из OpenStreetMap (кроме approx).
const dostykPlaces = <Place>[
  Place(
    id: 'bank', name: 'Банк', sub: 'Halyk Bank · ул. Ы. Алибаева',
    icon: Icons.account_balance_outlined, color: Color(0xFF2F7BEA),
    point: LatLng(45.25570, 82.48545),
    synonyms: ['халык', 'halyk', 'банкомат', 'kaspi', 'каспи'],
  ),
  Place(
    id: 'akimat', name: 'Акимат', sub: 'Сельский акимат',
    icon: Icons.account_balance_rounded, color: Color(0xFF4A5160),
    point: LatLng(45.25623, 82.49204),
    synonyms: ['әкімдік', 'акимдик', 'администрация', 'аким'],
  ),
  Place(
    id: 'rail', name: 'Вокзал', sub: 'Железнодорожный вокзал Достык',
    icon: Icons.train_outlined, color: Color(0xFF6E56CF),
    point: LatLng(45.25286, 82.48665),
    synonyms: ['станция', 'жд', 'темир жол', 'поезд'],
    chip: true,
  ),
  Place(
    id: 'kpp', name: 'Таможня · КПП', sub: 'Пограничный переход',
    icon: Icons.security_rounded, color: Color(0xFF0B7A75),
    point: LatLng(45.23342, 82.52075),
    synonyms: ['таможня', 'кпп', 'граница', 'шекара', 'кеден', 'пост'],
    chip: true,
  ),
  Place(
    id: 'hosp', name: 'Больница', sub: 'Поликлиника с. Достык',
    icon: Icons.local_hospital_outlined, color: Color(0xFFE5484D),
    point: LatLng(45.25161, 82.50019),
    synonyms: ['больничка', 'аурухана', 'поликлиника', 'скорая', 'врач', 'емхана'],
    chip: true,
  ),
  Place(
    id: 'apteka', name: 'Аптека', sub: 'Возле базара',
    icon: Icons.local_pharmacy_outlined, color: Color(0xFF13A35A),
    point: LatLng(45.25529, 82.48529),
    synonyms: ['дарыхана', 'лекарства'],
  ),
  Place(
    id: 'bazar', name: 'Базар', sub: 'Рынок',
    icon: Icons.shopping_bag_outlined, color: Color(0xFFD97A00),
    point: LatLng(45.25495, 82.48624),
    synonyms: ['рынок', 'нарык', 'базар'],
    chip: true,
  ),
  // В OSM отмечена одна школа («Школа с. Достык», ул. Молдагулова) — считаем её «Достық».
  Place(
    id: 'school-dostyq', name: 'Достық орта мектебі', sub: 'Школа «Достық» · ул. Молдагулова',
    icon: Icons.school_outlined, color: Color(0xFFD97A00),
    point: LatLng(45.25306, 82.49387),
    synonyms: ['школа', 'мектеп', 'сш', 'достык', 'средняя школа'],
    chip: true, group: 'school',
  ),
  Place(
    id: 'school-keleshek', name: 'Школа «Келешек»', sub: 'Келешек · место уточняется',
    icon: Icons.school_outlined, color: Color(0xFFD97A00),
    point: LatLng(45.25850, 82.48950),
    synonyms: ['школа', 'мектеп', 'келешек', 'kelechek'],
    chip: true, group: 'school', approx: true,
  ),
  Place(
    id: 'school-momyshuly', name: 'Школа им. Б. Момышұлы', sub: 'Место уточняется',
    icon: Icons.school_outlined, color: Color(0xFFD97A00),
    point: LatLng(45.25400, 82.49600),
    synonyms: ['школа', 'мектеп', 'момышулы', 'момышұлы', 'бауыржан'],
    chip: true, group: 'school', approx: true,
  ),
  Place(
    id: 'post', name: 'Почта', sub: 'Казпочта · место уточняется',
    icon: Icons.mail_outline_rounded, color: Color(0xFF4A5160),
    point: LatLng(45.25550, 82.48950),
    synonyms: ['казпочта', 'пошта', 'посылка'],
    approx: true,
  ),
  Place(
    id: 'mosque', name: 'Мечеть', sub: 'Место уточняется',
    icon: Icons.mosque_outlined, color: Color(0xFF6E56CF),
    point: LatLng(45.25480, 82.49150),
    synonyms: ['мешіт', 'мешит', 'намаз'],
    approx: true,
  ),
];

// ─── Поиск с опечатками (порт из прототипа) ──────────────────────────────

const _kz = {
  'ә': 'а', 'ө': 'о', 'ү': 'у', 'ұ': 'у', 'қ': 'к', 'ғ': 'г', 'ң': 'н',
  'һ': 'х', 'і': 'и', 'ё': 'е', 'й': 'и', 'ъ': '', 'ь': '',
};
const _digraphs = [
  ['sh', 'ш'], ['ch', 'ч'], ['zh', 'ж'], ['kh', 'х'], ['ya', 'я'], ['yu', 'ю'], ['ts', 'ц'],
];
const _lat = {
  'a': 'а', 'b': 'б', 'v': 'в', 'g': 'г', 'd': 'д', 'e': 'е', 'z': 'з', 'i': 'и',
  'k': 'к', 'l': 'л', 'm': 'м', 'n': 'н', 'o': 'о', 'p': 'п', 'r': 'р', 's': 'с',
  't': 'т', 'u': 'у', 'f': 'ф', 'h': 'х', 'c': 'к', 'y': 'ы', 'j': 'ж', 'w': 'в',
  'x': 'кс', 'q': 'к',
};
const _qw = "qwertyuiop[]asdfghjkl;'zxcvbnm,.";
const _ru = 'йцукенгшщзхъфывапролджэячсмитьбю';
const _stop = {'улица', 'ул', 'кошеси', 'проспект', 'пр', 'переулок', 'пер', 'мкр', 'дом', 'д'};

String _clean(String t) {
  final b = StringBuffer();
  for (final ch in t.split('')) {
    b.write(_kz[ch] ?? ch);
  }
  final s = b
      .toString()
      .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
      .trim();
  return s.split(' ').where((w) => w.isNotEmpty && !_stop.contains(w)).join(' ');
}

String _norm(String t) => _clean(t.toLowerCase());

String _translit(String t) {
  for (final d in _digraphs) {
    t = t.replaceAll(d[0], d[1]);
  }
  return t.split('').map((c) => _lat[c] ?? c).join();
}

String _layout(String t) => t.split('').map((c) {
      final i = _qw.indexOf(c);
      return i >= 0 ? _ru[i] : c;
    }).join();

int _lev(String a, String b) {
  if (a == b) return 0;
  final v = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    var prev = v[0];
    v[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final tmp = v[j];
      v[j] = min(min(v[j] + 1, v[j - 1] + 1), prev + (a[i - 1] == b[j - 1] ? 0 : 1));
      prev = tmp;
    }
  }
  return v[b.length];
}

double _wscore(String q, String w) {
  if (w.startsWith(q)) return 100 - (w.length - q.length) * .5;
  if (q.length >= 3 && w.contains(q)) return 70;
  final tol = q.length >= 7 ? 2 : q.length >= 4 ? 1 : 0;
  if (tol == 0) return 0;
  String cut(int n) => w.substring(0, min(w.length, max(1, n)));
  final d = [cut(q.length), cut(q.length + 1), cut(q.length - 1)]
      .map((s) => _lev(q, s))
      .reduce(min);
  return d <= tol ? 60.0 - d * 12 : 0;
}

double _tscore(List<String> qw, String cand) {
  final ws = cand.split(' ');
  var tot = 0.0;
  for (final q in qw) {
    var best = 0.0;
    for (final w in ws) {
      best = max(best, _wscore(q, w));
    }
    if (best == 0) return 0;
    tot += best;
  }
  return tot / qw.length;
}

List<Place> searchPlaces(String raw) {
  final lo = raw.toLowerCase();
  final variants = <String>[_clean(lo)];
  if (RegExp(r'[a-z]').hasMatch(lo)) {
    variants.add(_clean(_layout(lo)));
    variants.add(_clean(_translit(lo)));
  }
  final scored = <Place, double>{};
  for (var vi = 0; vi < variants.length; vi++) {
    final words = variants[vi].split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) continue;
    for (final p in dostykPlaces) {
      var best = 0.0;
      for (final k in [p.name, p.sub, ...p.synonyms]) {
        best = max(best, _tscore(words, _norm(k)));
      }
      if (best > 0) {
        final sc = best - (vi > 0 ? 6 : 0);
        if (sc > (scored[p] ?? 0)) scored[p] = sc;
      }
    }
  }
  final list = scored.keys.toList()..sort((a, b) => scored[b]!.compareTo(scored[a]!));
  return list;
}

Place? nearestPlace(LatLng p, {double maxMeters = 250}) {
  final d = Distance();
  Place? best;
  var bd = maxMeters;
  for (final pl in dostykPlaces) {
    final m = d(p, pl.point);
    if (m < bd) {
      bd = m;
      best = pl;
    }
  }
  return best;
}

String formatDistance(double meters) => meters < 1000
    ? '${(meters / 10).round() * 10} м'
    : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} км';
