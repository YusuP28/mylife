import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Password Generator', () {
    String generateRandomPassword(int length, bool useSymbols) {
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      const symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?';
      final pool = useSymbols ? chars + symbols : chars;
      final random = Random.secure();
      return List.generate(length, (_) => pool[random.nextInt(pool.length)]).join();
    }

    test('generates password of correct length (alphanumeric)', () {
      for (int len = 4; len <= 128; len += 10) {
        final pwd = generateRandomPassword(len, false);
        expect(pwd.length, len);
      }
    });

    test('generates password of correct length (with symbols)', () {
      for (int len = 4; len <= 128; len += 10) {
        final pwd = generateRandomPassword(len, true);
        expect(pwd.length, len);
      }
    });

    test('alphanumeric passwords only contain allowed chars', () {
      const allowed = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      for (int i = 0; i < 100; i++) {
        final pwd = generateRandomPassword(32, false);
        for (final char in pwd.codeUnits) {
          expect(allowed.contains(String.fromCharCode(char)), true);
        }
      }
    });

    test('symbolic passwords only contain allowed chars', () {
      const allowed = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_=+[]{}|;:,.<>?';
      for (int i = 0; i < 100; i++) {
        final pwd = generateRandomPassword(32, true);
        for (final char in pwd.codeUnits) {
          expect(allowed.contains(String.fromCharCode(char)), true);
        }
      }
    });

    test('passwords are different each time', () {
      final pwd1 = generateRandomPassword(16, false);
      final pwd2 = generateRandomPassword(16, false);
      expect(pwd1, isNot(pwd2));
    });

    test('secure random produces uniform distribution', () {
      const pool = 'ab';
      final random = Random.secure();
      final counts = { 'a': 0, 'b': 0 };
      for (int i = 0; i < 10000; i++) {
        final char = pool[random.nextInt(pool.length)];
        counts[char] = counts[char]! + 1;
      }
      // Should be roughly 50/50 (within 5%)
      expect(counts['a']!, greaterThan(4500));
      expect(counts['a']!, lessThan(5500));
    });
  });
}