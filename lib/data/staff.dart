/// Сотрудник админки: менеджер или админ. Добавляется по номеру телефона.
class StaffMember {
  /// Последние 10 цифр номера, например 7771234567.
  final String phone;
  final String role; // manager / admin
  final String name;

  /// Человек уже входил с этого номера.
  final bool joined;
  const StaffMember({required this.phone, required this.role, required this.name, required this.joined});
}

abstract class StaffRepository {
  Future<List<StaffMember>> list();

  /// role: manager / admin; client — убрать доступ.
  Future<void> set(String phone, String role, {String name = ''});
}
