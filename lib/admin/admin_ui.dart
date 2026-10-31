import 'package:flutter/material.dart';
import '../theme.dart';

/// Общие детали админки в стиле reference/admin-prototype.html.

/// Запрос из общего поиска в шапке — его подхватывает раздел «Заказы».
final adminSearch = ValueNotifier<String>('');

/// Карточка: без рамки, мягкая тень, скругление 20.
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: context.paper,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x0A111317), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(color: Color(0x0D111317), blurRadius: 18, offset: Offset(0, 4)),
          ],
        ),
        child: child,
      );
}

/// Заголовок раздела: крупное название и подпись.
class AdminHead extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trailing;
  const AdminHead({super.key, required this.title, this.sub, this.trailing});

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 10,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(color: context.ink, fontSize: 26, fontWeight: FontWeight.w800)),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(sub!, style: TextStyle(color: context.muted, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
          if (trailing != null) trailing!,
        ],
      );
}

enum PillTone { ok, warn, bad, info, mute, violet }

/// Статус-«таблетка» с точкой.
class StatusPill extends StatelessWidget {
  final String text;
  final PillTone tone;
  const StatusPill(this.text, this.tone, {super.key});

  static (Color, Color) colors(PillTone t) => switch (t) {
        PillTone.ok => (const Color(0xFFE4F6EC), const Color(0xFF0B6B3B)),
        PillTone.warn => (const Color(0xFFFFF1DE), const Color(0xFFC26A00)),
        PillTone.bad => (const Color(0xFFFDEBEC), const Color(0xFFD93A3F)),
        PillTone.info => (const Color(0xFFE8F0FE), const Color(0xFF2B6CF6)),
        PillTone.violet => (const Color(0xFFEFEBFF), const Color(0xFF6E56CF)),
        PillTone.mute => (const Color(0xFFF3F4F6), const Color(0xFF6B7079)),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Переключатель-фильтр: выбранный — чёрный.
class FilterChips<T> extends StatelessWidget {
  final Map<T, String> items;
  final T value;
  final ValueChanged<T> onChanged;
  const FilterChips({super.key, required this.items, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in items.entries)
            Material(
              color: e.key == value ? context.ink : context.paper,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: e.key == value ? context.ink : context.lineC),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(e.key),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: Text(e.value,
                      style: TextStyle(
                        color: e.key == value ? context.paper : context.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      )),
                ),
              ),
            ),
        ],
      );
}

/// Поле поиска со значком лупы.
class SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  const SearchBox({super.key, required this.hint, required this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 40, minWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: context.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: TextStyle(color: context.ink, fontSize: 14),
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Заголовок столбца таблицы: мелкие прописные.
Widget thCell(BuildContext context, String t, {bool right = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(t.toUpperCase(),
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(color: context.muted, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .6)),
    );

Widget tdCell(Widget child, {bool right = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Align(alignment: right ? Alignment.centerRight : Alignment.centerLeft, child: child),
    );
