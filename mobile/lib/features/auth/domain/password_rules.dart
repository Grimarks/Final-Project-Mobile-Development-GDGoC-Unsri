// syarat kuat kayak password mobile banking, mesti sama persis sama backend
// (ensure_strong_password di app/schemas/auth.py) biar gak beda validasi.
// dipake register DAN ganti password
final _strongPassword = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');

bool isStrongPassword(String value) => _strongPassword.hasMatch(value);
