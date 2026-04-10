/// ユーザープロフィールエンティティ
///
/// Domain 層に属するため、dio / HTTP を一切知らない純粋な Dart クラス。
/// JSONPlaceholder API の /users/{id} レスポンスをもとに設計。
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.website,
    required this.companyName,
  });

  final int id;
  final String name;
  final String email;
  final String phone;
  final String website;
  final String companyName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          other.id == id &&
          other.name == name &&
          other.email == email;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode;

  @override
  String toString() => 'UserProfile(id: $id, name: $name, email: $email)';
}
