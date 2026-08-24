import 'package:flutter_test/flutter_test.dart';
import 'package:witsgame/core/errors/monetization_exceptions.dart';

void main() {
  test('recognizes only the exact free-host quota message', () {
    expect(isFreeHostLimitReachedMessage('FREE_HOST_LIMIT_REACHED'), isTrue);
    expect(isFreeHostLimitReachedMessage('P0001'), isFalse);
    expect(
      isFreeHostLimitReachedMessage('FREE_HOST_LIMIT_REACHED now'),
      isFalse,
    );
  });
}
