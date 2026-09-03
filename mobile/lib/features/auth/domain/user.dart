class AppUser {
  const AppUser({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  // huruf depan nama, buat avatar
  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  String get firstName => name.split(' ').first;
}
