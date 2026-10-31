import 'dart:async';
import '../orders.dart';
import 'sb_client.dart';

class SupabaseOrderRepository implements OrderRepository {
  static DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static List<Bid> _bids(Object? v) {
    if (v is! Map) return const [];
    final list = <Bid>[
      for (final e in v.entries)
        if (e.value is Map)
          Bid(
            driverId: '${e.key}',
            driverName: e.value['driverName'] as String? ?? '',
            car: e.value['car'] as String? ?? '',
            plate: e.value['plate'] as String? ?? '',
            price: (e.value['price'] as num?)?.toInt() ?? 0,
            at: _time(e.value['at']),
          ),
    ];
    list.sort((a, b) => a.price.compareTo(b.price));
    return list;
  }

  static TaxiOrder _order(Map<String, dynamic> m) => TaxiOrder(
        id: m['id'] as String,
        status: m['status'] as String? ?? 'searching',
        // Заказ по звонку: в Firestore был clientId "manager:<uid>".
        clientId: m['client_id'] as String? ??
            (m['manager_id'] != null ? 'manager:${m['manager_id']}' : ''),
        clientName: m['client_name'] as String? ?? '',
        clientPhone: m['client_phone'] as String? ?? '',
        createdBy: m['created_by'] as String? ?? 'app',
        comment: m['comment'] as String? ?? '',
        clientPrice: (m['client_price'] as num?)?.toInt(),
        bids: _bids(m['bids']),
        from: m['from_label'] as String? ?? '',
        fromLat: (m['from_lat'] as num?)?.toDouble(),
        fromLng: (m['from_lng'] as num?)?.toDouble(),
        to: m['to_label'] as String? ?? '',
        tariff: m['service'] as String? ?? 'local',
        price: (m['price'] as num?)?.toInt() ?? 0,
        payment: m['payment'] as String? ?? 'cash',
        driverId: m['driver_id'] as String?,
        driverName: m['driver_name'] as String?,
        driverCar: m['driver_car'] as String?,
        driverPlate: m['driver_plate'] as String?,
        clientComingOut: m['client_coming_out'] as bool? ?? false,
        declinedBy: (m['declined_by'] as List?)?.whereType<String>().toList() ?? const [],
        createdAt: _time(m['created_at']),
      );

  @override
  Future<String> create({
    required String clientId,
    required String clientName,
    required String from,
    Geo? fromGeo,
    required String to,
    Geo? toGeo,
    required String region,
    required String tariff,
    required int price,
    required String payment,
    String clientPhone = '',
    String createdBy = 'app',
    String comment = '',
    int? clientPrice,
  }) async {
    final byManager = clientId.startsWith('manager:');
    final row = await sb
        .from('orders')
        .insert({
          if (byManager) 'manager_id': clientId.substring('manager:'.length) else 'client_id': clientId,
          'client_name': clientName,
          'client_phone': clientPhone,
          'from_label': from,
          'from_lat': fromGeo?.lat,
          'from_lng': fromGeo?.lng,
          'to_label': to,
          'to_lat': toGeo?.lat,
          'to_lng': toGeo?.lng,
          'region': region,
          'service': tariff,
          'price': price,
          'payment': payment,
          'created_by': createdBy,
          if (comment.isNotEmpty) 'comment': comment,
          if (clientPrice != null) 'client_price': clientPrice,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  @override
  Stream<TaxiOrder?> watch(String id) => sb
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('id', id)
      .map((rows) => rows.isEmpty ? null : _order(rows.first));

  // Опрос раз в 3 секунды, а не realtime: взятый другим водителем заказ правила базы
  // скрывают, и realtime об этом не сообщает — заказ «завис» бы в списке.
  @override
  Stream<List<TaxiOrder>> watchSearching(String region) async* {
    while (true) {
      try {
        final rows = await sb
            .from('orders')
            .select()
            .eq('region', region)
            .eq('status', 'searching')
            .order('created_at', ascending: true);
        yield rows.map(_order).toList();
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  @override
  Stream<List<TaxiOrder>> watchRegion(String region) => sb
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('region', region)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(_order).toList());

  @override
  Stream<List<TaxiOrder>> watchAssigned(String driverId) => sb
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('driver_id', driverId)
      .map((rows) => rows.map(_order).toList());

  // Сервер сам берёт имя и машину водителя из его анкеты.
  @override
  Future<bool> accept(String id,
      {required String driverId, required String driverName, String? car, String? plate}) async {
    final self = driverId == sb.auth.currentUser?.id;
    final ok = await sb.rpc('accept_order', params: {
      'p_order': id,
      if (!self) 'p_driver': driverId,
    });
    return ok == true;
  }

  @override
  Future<void> setStatus(String id, String status) => status == 'cancelled'
      ? sb.rpc('cancel_order', params: {'p_order': id})
      : sb.rpc('advance_order', params: {'p_order': id, 'p_status': status});

  @override
  Future<void> placeBid(String id, Bid bid) =>
      sb.rpc('place_bid', params: {'p_order': id, 'p_price': bid.price});

  @override
  Future<bool> chooseBid(String id, Bid bid) async =>
      await sb.rpc('choose_bid', params: {'p_order': id, 'p_driver': bid.driverId}) == true;

  @override
  Future<void> release(String id, String driverId) =>
      sb.rpc('release_order', params: {'p_order': id});

  // Клиент меняет только «выхожу» и оценку — у каждого своё действие на сервере.
  @override
  Future<void> update(String id, Map<String, Object?> fields) async {
    if (fields['clientComingOut'] == true) {
      await sb.rpc('client_coming_out', params: {'p_order': id});
    }
    final rating = fields['rating'];
    if (rating is int) {
      await sb.rpc('rate_order', params: {'p_order': id, 'p_stars': rating});
    }
  }

  @override
  Future<String> userName(String uid) async => (await userProfile(uid)).name;

  @override
  Future<({String name, String role})> userProfile(String uid) async {
    final m = await sb.from('profiles').select('name, role').eq('id', uid).maybeSingle();
    return (name: m?['name'] as String? ?? '', role: m?['role'] as String? ?? 'client');
  }

  @override
  Future<void> updateDriverLocation(String uid, Geo geo) => sb
      .from('drivers')
      .update({'lat': geo.lat, 'lng': geo.lng, 'location_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', uid);

  @override
  Future<void> setDriverOnline(String uid, bool online, String region) => sb
      .from('drivers')
      .update({'status': online ? 'online' : 'offline', 'region': region})
      .eq('id', uid);

  @override
  Stream<Geo?> watchDriverLocation(String uid) => sb
      .from('drivers')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map((rows) {
        if (rows.isEmpty) return null;
        final lat = (rows.first['lat'] as num?)?.toDouble();
        final lng = (rows.first['lng'] as num?)?.toDouble();
        return lat == null || lng == null ? null : (lat: lat, lng: lng);
      });

  // Машины на линии — из открытого списка без телефонов (online_drivers); раз в 10 секунд.
  @override
  Stream<List<Geo>> watchOnlineDrivers(String region) async* {
    while (true) {
      try {
        final rows = await sb.from('online_drivers').select('lat, lng').eq('region', region);
        yield [
          for (final m in rows)
            if (m['lat'] != null && m['lng'] != null)
              (lat: (m['lat'] as num).toDouble(), lng: (m['lng'] as num).toDouble()),
        ];
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  }
}
