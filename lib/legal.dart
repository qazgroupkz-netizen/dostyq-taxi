import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'i18n.dart';
import 'services/open_link.dart';

/// Документы лежат на сайте: папка legal/ в репозитории копируется туда при сборке.
const kLegalBase = 'https://alakoltaxi.kz/legal/';

enum LegalDoc { privacy, terms, driverOffer }

String legalUrl(LegalDoc d) => kLegalBase +
    switch (d) {
      LegalDoc.privacy => 'privacy.html',
      LegalDoc.terms => 'terms.html',
      LegalDoc.driverOffer => 'driver-offer.html',
    };

String legalTitle(LegalDoc d) => switch (d) {
      LegalDoc.privacy => tr('Политика конфиденциальности'),
      LegalDoc.terms => tr('Пользовательское соглашение'),
      LegalDoc.driverOffer => tr('Оферта для водителей'),
    };

/// В браузере открывает документ в новой вкладке, в APK — показывает ссылку с кнопкой «Скопировать».
void openLegal(BuildContext context, LegalDoc d) {
  final url = legalUrl(d);
  if (openLink(url)) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(legalTitle(d)),
      content: SelectableText(url),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            Navigator.pop(ctx);
          },
          child: Text(tr('Скопировать')),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Закрыть'))),
      ],
    ),
  );
}

/// Ссылка на документ — подчёркнутый текст.
class LegalLink extends StatelessWidget {
  final LegalDoc doc;
  final double fontSize;
  const LegalLink(this.doc, {super.key, this.fontSize = 13});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => openLegal(context, doc),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            legalTitle(doc),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
}
