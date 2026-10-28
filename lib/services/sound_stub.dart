import 'package:flutter/services.dart';

void unlockSound() {}

// На Android настоящий звук придёт вместе с push-уведомлениями (этап 7).
void playAlert() {
  HapticFeedback.heavyImpact();
  SystemSound.play(SystemSoundType.alert);
}
