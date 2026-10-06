import 'package:campusflow/features/auth/domain/password_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aturan yang sama dipakai register & ganti password, sama dengan backend.
void main() {
  test('password kuat diterima', () {
    expect(isStrongPassword('Password123!'), isTrue);
  });

  test('password tanpa simbol / huruf besar / angka / kurang 8 ditolak', () {
    expect(isStrongPassword('newpassword123'), isFalse);
    expect(isStrongPassword('NewPassword123'), isFalse);
    expect(isStrongPassword('Password!!'), isFalse);
    expect(isStrongPassword('Pa1!'), isFalse);
  });
}
