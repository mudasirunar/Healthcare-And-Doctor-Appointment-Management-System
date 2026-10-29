import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_app/core/utils/date_time_utils.dart';

void main() {
  group('Challenge #2: Timezone Architecture & Conversions', () {
    test('Converts DateTime to ISO-8601 UTC string consistently', () {
      final local = DateTime(2026, 11, 15, 14, 30);
      final utcIso = DateTimeUtils.toUtcIsoString(local);

      expect(utcIso.endsWith('Z'), isTrue);
      final parsed = DateTime.parse(utcIso);
      expect(parsed.isUtc, isTrue);
    });

    test('Parses UTC string into user local timezone correctly', () {
      const utcString = '2026-11-15T10:00:00.000Z';
      final localDt = DateTimeUtils.parseUtcToLocal(utcString);

      expect(localDt.isUtc, isFalse);
      expect(localDt.toUtc(), equals(DateTime.parse(utcString)));
    });

    test('Generates deterministic slot lock key with zero collisions', () {
      final slotUtc = DateTime.utc(2026, 11, 2, 9, 30);
      const docId = 'doc_cardio_99';

      final key = DateTimeUtils.generateSlotKey(docId, slotUtc);
      expect(key, equals('doc_cardio_99_20261102T0930'));

      // Different minute generates different key
      final keyDifferentMinute = DateTimeUtils.generateSlotKey(docId, DateTime.utc(2026, 11, 2, 9, 31));
      expect(key, isNot(equals(keyDifferentMinute)));
    });

    test('Local timezone name indicator is non-empty and legible', () {
      final tz = DateTimeUtils.getTimeZoneName();
      expect(tz, isNotEmpty);
    });

    test('Full date time with timezone contains date and time and zone badge', () {
      const utcString = '2026-11-02T09:00:00.000Z';
      final full = DateTimeUtils.formatFullWithTimeZone(utcString);

      expect(full, contains('Nov 2, 2026'));
      expect(full, contains('('));
      expect(full, contains(')'));
    });
  });
}
