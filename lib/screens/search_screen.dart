import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<(String, String, String)> _results = [];
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _results = mockPlaces.cast();
    _ctrl.addListener(_onInput);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onInput() {
    final q = _ctrl.text.trim().toLowerCase();
    setState(() {
      _hasInput = q.isNotEmpty;
      if (q.isEmpty) {
        _results = mockPlaces.cast();
      } else {
        _results = mockPlaces
            .where((p) =>
                p.$1.toLowerCase().contains(q) ||
                p.$2.toLowerCase().contains(q))
            .toList()
            .cast();
      }
    });
  }

  void _pick(String name) {
    final state = context.read<AppState>();
    state.setDestination(name);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          // Верхняя часть
          Container(
            color: context.paper,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 8,
            ),
            child: Column(
              children: [
                // Заголовок
                Row(
                  children: [
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Маршрут',
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Поля откуда/куда
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Откуда
                      _RouteRow(
                        isFrom: true,
                        value: 'Моё местоположение',
                        readOnly: true,
                        ctx: context,
                      ),
                      Divider(height: 1, color: context.lineC),
                      // Куда
                      _RouteRow(
                        isFrom: false,
                        value: '',
                        ctrl: _ctrl,
                        autofocus: true,
                        ctx: context,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // «Указать на карте»
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Карта появится на этапе 4'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.taxiSft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.jLine),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: context.taxi, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Указать на карте',
                                  style: TextStyle(
                                    color: context.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  )),
                              Text('Если нужного адреса нет в списке',
                                  style: TextStyle(
                                    color: context.muted,
                                    fontSize: 12.5,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Список мест
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (!_hasInput)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'МЕСТА В ДОСТЫКЕ',
                      style: TextStyle(
                        color: context.taxi,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .08 * 12,
                      ),
                    ),
                  ),
                ..._results.map((p) => _PlaceItem(
                      name: p.$1,
                      sub: p.$2,
                      emoji: p.$3,
                      onTap: () => _pick(p.$1),
                      ctx: context,
                    )),
                if (_hasInput && _ctrl.text.trim().isNotEmpty)
                  _PlaceItem(
                    name: _ctrl.text.trim(),
                    sub: 'Записать как есть',
                    emoji: '📍',
                    onTap: () => _pick(_ctrl.text.trim()),
                    ctx: context,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final bool isFrom;
  final String value;
  final TextEditingController? ctrl;
  final bool readOnly;
  final bool autofocus;
  final BuildContext ctx;

  const _RouteRow({
    required this.isFrom,
    required this.value,
    this.ctrl,
    this.readOnly = false,
    this.autofocus = false,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: isFrom ? ctx.ink : ctx.taxi,
              borderRadius: isFrom
                  ? BorderRadius.circular(5)
                  : BorderRadius.circular(3),
              boxShadow: isFrom
                  ? null
                  : [BoxShadow(color: ctx.taxi.withOpacity(.3), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: readOnly
                ? Container(
                    height: 54,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: ctx.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : SizedBox(
                    height: 54,
                    child: TextField(
                      controller: ctrl,
                      autofocus: autofocus,
                      style: TextStyle(
                        color: ctx.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Улица и дом или место',
                        hintStyle: TextStyle(
                          color: ctx.hint,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaceItem extends StatelessWidget {
  final String name, sub, emoji;
  final VoidCallback onTap;
  final BuildContext ctx;
  const _PlaceItem({
    required this.name, required this.sub,
    required this.emoji, required this.onTap,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: ctx.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 66),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ctx.lineC, width: 1),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: TextStyle(
                          color: ctx.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(sub,
                        style: TextStyle(
                          color: ctx.muted, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
