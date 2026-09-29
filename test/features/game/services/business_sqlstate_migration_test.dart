import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remove bet hotfix does not use serialization failure SQLSTATE', () {
    final migration = File(
      'supabase/migrations/'
      '20260927230745_fix_remove_bet_closed_phase_retry_loop.sql',
    ).readAsStringSync();

    expect(migration, isNot(contains("errcode = '40001'")));
    expect(migration, contains("raise exception 'Betting phase is closed'"));
  });

  test('business 40001 hardening rewrites only SQLSTATE declarations', () {
    final migration = File(
      'supabase/migrations/'
      '20260929191000_replace_business_40001_sqlstate_v1.sql',
    ).readAsStringSync();

    expect(migration, contains("pg_get_functiondef(p.oid) ilike '%40001%'"));
    expect(migration, contains("'errcode = ''P0001'''"));
    expect(migration, contains('execute v_rewritten'));
  });
}
