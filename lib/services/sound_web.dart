import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

web.HTMLAudioElement? _audio;
bool _unlocked = false;

web.HTMLAudioElement _el() => _audio ??= web.HTMLAudioElement()
  ..src = _chimeDataUri()
  ..preload = 'auto';

/// Safari на iPhone разрешает звук только после касания пользователя:
/// при первом касании «прогреваем» элемент беззвучно.
void unlockSound() {
  if (_unlocked) return;
  _unlocked = true;
  final a = _el();
  a.muted = true;
  a.play().toDart.then((_) {
    a.pause();
    a.currentTime = 0;
    a.muted = false;
  }).catchError((_) {
    a.muted = false;
    _unlocked = false;
  });
}

void playAlert() {
  final a = _el();
  a.currentTime = 0;
  a.play().toDart.catchError((_) => null);
}

String _chimeDataUri() {
  const rate = 22050;
  final samples = <int>[];
  void tone(double freq, double sec) {
    final n = (rate * sec).round();
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      final env = exp(-4 * t / sec) * min(1.0, i / 200);
      samples.add((sin(2 * pi * freq * t) * env * 0.6 * 32767).round());
    }
  }

  void gap(double sec) => samples.addAll(List.filled((rate * sec).round(), 0));

  tone(880, .18);
  tone(1320, .32);
  gap(.12);
  tone(880, .18);
  tone(1320, .32);

  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return 'data:audio/wav;base64,${base64Encode(data.buffer.asUint8List())}';
}
