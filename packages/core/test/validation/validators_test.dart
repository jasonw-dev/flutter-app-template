import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('required', () {
    test('null / 空字串 / 只有空白 → 回 key', () {
      expect(Validators.required(null), 'validationRequired');
      expect(Validators.required(''), 'validationRequired');
      expect(Validators.required('   '), 'validationRequired');
      expect(Validators.required('\t\n'), 'validationRequired');
    });

    test('有內容 → null', () {
      expect(Validators.required('a'), isNull);
      expect(Validators.required('  a  '), isNull);
    });
  });

  group('email', () {
    test('合法格式通過', () {
      expect(Validators.email('a@b.c'), isNull);
      expect(Validators.email('jason+tag@example.co.uk'), isNull);
    });

    test('不合法格式回 key', () {
      for (final bad in ['abc', 'a@b', '@b.c', 'a b@c.d', 'a@b c.d']) {
        expect(Validators.email(bad), 'validationEmail', reason: bad);
      }
    });

    test('空字串回 null——空值交給 required 管', () {
      // 這條釘住「兩個 validator 各司其職」的設計:email 不做必填檢查,
      // 需要必填就與 required 併用。
      expect(Validators.email(''), isNull);
      expect(Validators.email(null), isNull);
    });
  });

  group('minLength', () {
    test('邊界:剛好等於 min 要通過', () {
      expect(Validators.minLength('123456', 6), isNull);
      expect(Validators.minLength('12345', 6), 'validationMinLength');
    });

    test('null 視為長度 0', () {
      expect(Validators.minLength(null, 1), 'validationMinLength');
      expect(Validators.minLength(null, 0), isNull);
    });
  });

  group('all', () {
    test('回傳第一個失敗的 key,不是最後一個', () {
      // 空字串同時違反 required 與 minLength;必須拿到 required。
      final error = Validators.all('', [
        Validators.required,
        (v) => Validators.minLength(v, 6),
      ]);
      expect(error, 'validationRequired');
    });

    test('全部通過回 null', () {
      expect(
        Validators.all('a@b.c', [Validators.required, Validators.email]),
        isNull,
      );
    });

    test('空規則清單回 null', () {
      expect(Validators.all(null, const []), isNull);
    });
  });
}
