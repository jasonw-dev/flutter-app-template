import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('依 minLevel 過濾並格式化輸出', () {
    final lines = <String>[];
    ConsoleLogger(minLevel: LogLevel.info, output: lines.add)
      ..debug('skip me')
      ..info('hello')
      ..error('boom', error: 'cause');
    expect(lines, hasLength(3));
    expect(lines[0], '[INFO] hello');
    expect(lines[1], '[ERROR] boom');
    expect(lines[2], contains('cause'));
  });

  test('可當 AppLogger 注入', () {
    expect(ConsoleLogger(), isA<AppLogger>());
  });
}
