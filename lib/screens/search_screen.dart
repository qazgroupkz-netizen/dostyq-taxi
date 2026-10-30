import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show Distance;
import 'package:provider/provider.dart';
import '../data/places.dart';
import '../state.dart';
import '../theme.dart';

class SearchScreen extends StatefulWidget {
  /// true — выбираем «Откуда», иначе «Куда».
  final bool forFrom;
  const SearchScreen({super.key, this.forFrom = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  late bool _forFrom = widget.forFrom;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _q = _ctrl.text.trim()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _choose(Place p) {
    final state = context.read<AppState>();
    if (_forFrom) {
      state.setPickupPlace(p.name, p.point);
    } else {
      state.setDestination(p.name, p.point);
    }
    Navigator.of(context).pop();
  }

  void _pickOnMap() {
    context.read<AppState>().startPick(_forFrom ? 'from' : 'to');
    Navigator.of(context).pop();
  }

  Future<void> _useGps() async {
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await state.pickupFromGps();
    if (state.myLocation == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Не удалось определить местоположение. '
            'Разрешите доступ к геолокации в настройках браузера.'),
      ));
      return;
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final results = _q.isEmpty ? state.places : searchPlaces(_q, state.places);
    final dist = Distance();

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          Container(
            color: context.paper,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 8,
            ),
            child: Column(
              children: [
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
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _RouteRow(
                        isFrom: true,
                        active: _forFrom,
                        value: state.fromAddress,
                        ctrl: _forFrom ? _ctrl : null,
                        hint: 'Откуда: улица, дом или место',
                        onTap: () => setState(() {
                          _forFrom = true;
                          _ctrl.clear();
                        }),
                      ),
                      Divider(height: 1, color: context.lineC),
                      _RouteRow(
                        isFrom: false,
                        active: !_forFrom,
                        value: state.destination,
                        ctrl: _forFrom ? null : _ctrl,
                        hint: 'Куда: улица, дом или место',
                        onTap: () => setState(() {
                          _forFrom = false;
                          _ctrl.clear();
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickOnMap,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.taxiSft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.jLine),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: context.taxi, size: 22),
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
                                  style: TextStyle(color: context.muted, fontSize: 12.5)),
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    _q.isNotEmpty
                        ? 'ПОДСКАЗКИ'
                        : _forFrom ? 'ОТКУДА ВАС ЗАБРАТЬ' : 'МЕСТА В ДОСТЫКЕ',
                    style: TextStyle(
                      color: context.taxi,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .08 * 12,
                    ),
                  ),
                ),
                if (_forFrom && _q.isEmpty)
                  _PlaceItem(
                    name: 'Моё местоположение',
                    sub: 'По GPS',
                    icon: Icons.near_me_rounded,
                    iconColor: context.taxi,
                    onTap: _useGps,
                  ),
                ...results.map((p) => _PlaceItem(
                      name: p.name,
                      sub: p.sub,
                      icon: p.icon,
                      iconColor: p.color,
                      trailing: formatDistance(dist(state.pickup, p.point)),
                      onTap: () => _choose(p),
                    )),
                if (_q.isNotEmpty && results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Ничего не нашли. Проверьте название или нажмите '
                      '«Указать на карте» выше.',
                      style: TextStyle(color: context.muted, fontSize: 15, height: 1.5),
                    ),
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
  final bool active;
  final String value;
  final String hint;
  final TextEditingController? ctrl;
  final VoidCallback onTap;

  const _RouteRow({
    required this.isFrom,
    required this.active,
    required this.value,
    required this.hint,
    required this.onTap,
    this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: context.ink,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: active ? context.taxi : Colors.transparent, width: 3),
        ),
      ),
      padding: const EdgeInsets.only(left: 13, right: 16),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: isFrom ? context.ink : context.taxi,
              borderRadius: BorderRadius.circular(isFrom ? 5 : 3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ctrl != null
                ? SizedBox(
                    height: 54,
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: style,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: value.isEmpty ? hint : value,
                        hintStyle: TextStyle(color: context.hint, fontWeight: FontWeight.w400),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 54,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value.isEmpty ? hint : value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: value.isEmpty
                            ? style.copyWith(color: context.hint, fontWeight: FontWeight.w400)
                            : style,
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
  final String name, sub;
  final IconData icon;
  final Color iconColor;
  final String? trailing;
  final VoidCallback onTap;

  const _PlaceItem({
    required this.name,
    required this.sub,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 66),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: context.lineC)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name,
                              style: TextStyle(
                                color: context.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              )),
                          Text(sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: context.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (trailing != null)
                      Text(trailing!,
                          style: TextStyle(
                            color: context.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
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
