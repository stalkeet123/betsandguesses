import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/services/game_trace_service.dart';

void main() {
  final trace = GameTraceService.instance;

  tearDown(() => trace.resetForTest());

  test('disabled tracing does not retain records', () {
    trace.resetForTest(enabled: false);

    trace.trace('ignored');

    expect(trace.export(), isEmpty);
  });

  test('trace records preserve ordered increasing sequences', () {
    trace.resetForTest(enabled: true);

    trace.trace('first');
    trace.trace('second');

    final export = trace.export();
    expect(export, contains('"event":"first"'));
    expect(export, contains('"event":"second"'));
    expect(export.indexOf('"seq":1'), lessThan(export.indexOf('"seq":2')));
  });

  test('ring buffer evicts its oldest trace record', () {
    trace.resetForTest(enabled: true);

    for (var index = 0; index < 2001; index++) {
      trace.trace('record_$index');
    }

    final export = trace.export();
    expect(export, isNot(contains('"event":"record_0"')));
    expect(export, contains('"event":"record_2000"'));
  });
}
