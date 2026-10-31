import '../staff.dart';
import 'sb_client.dart';

class SupabaseStaffRepository implements StaffRepository {
  @override
  Future<List<StaffMember>> list() async {
    final rows = await sb.rpc('staff_list') as List;
    return [
      for (final m in rows.cast<Map>())
        StaffMember(
          phone: m['phone'] as String? ?? '',
          role: m['role'] as String? ?? 'manager',
          name: m['name'] as String? ?? '',
          joined: m['joined'] as bool? ?? false,
        ),
    ];
  }

  @override
  Future<void> set(String phone, String role, {String name = ''}) =>
      sb.rpc('set_staff', params: {'p_phone': phone, 'p_role': role, 'p_name': name});
}
