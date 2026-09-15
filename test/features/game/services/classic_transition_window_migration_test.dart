import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/'
      '20260915225755_extend_classic_question_transition_window.sql',
    ).readAsStringSync();
  });

  test('uses one authoritative 1500 ms Classic question duration', () {
    expect(
      RegExp("interval '1500 milliseconds'").allMatches(migration),
      hasLength(1),
    );
    expect(
      migration,
      contains('private.classic_question_transition_duration_v1()'),
    );
  });

  test('start_game_v4 uses the authoritative question duration', () {
    final body = migration.substring(
      migration.indexOf('create or replace function public.start_game_v4'),
      migration.indexOf(
        'create or replace function public.claim_game_phase_v1',
      ),
    );

    expect(body, contains('private.classic_question_transition_duration_v1()'));
    expect(body, isNot(contains("interval '1 second'")));
  });

  test('next rounds use 1500 ms without changing other phase durations', () {
    final body = migration.substring(
      migration.indexOf(
        'create or replace function public.claim_game_phase_v1',
      ),
    );

    expect(
      body,
      contains(
        "when p_next_phase = 'question' then\n"
        '          v_started_at + '
        'private.classic_question_transition_duration_v1()',
      ),
    );
    expect(
      body,
      contains('else v_started_at + make_interval(secs => p_duration_seconds)'),
    );
  });
}
