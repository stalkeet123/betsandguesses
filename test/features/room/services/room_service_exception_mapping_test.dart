import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:witsgame/core/errors/monetization_exceptions.dart';
import 'package:witsgame/features/room/services/room_service.dart';

void main() {
  test('maps exact free host limit room-create rejection', () {
    final error = const PostgrestException(
      message: 'FREE_HOST_LIMIT_REACHED',
      code: 'P0001',
    );

    expect(
      roomCreationExceptionFor(error),
      isA<FreeHostLimitReachedException>(),
    );
  });

  test('does not map a different P0001 room-create rejection', () {
    final error = const PostgrestException(
      message: 'SOME_OTHER_RULE',
      code: 'P0001',
    );

    expect(roomCreationExceptionFor(error), isNull);
  });

  test('preserves premium setup room-create mappings', () {
    final error = const PostgrestException(
      message: 'PREMIUM_PLAYERS_REQUIRED',
      code: 'P0001',
    );

    final mapped = roomCreationExceptionFor(error);
    expect(mapped, isA<PremiumSetupRequiredException>());
    expect(
      (mapped! as PremiumSetupRequiredException).requirement,
      PremiumSetupRequirement.players,
    );
  });
}
