import 'package:flutter/material.dart';

import 'l10n.dart';

/// Ako dlho blokovať.
enum BlockDuration { hour, day, week, custom }

extension BlockDurationX on BlockDuration {
  String label(S s) => switch (this) {
        BlockDuration.hour => s.hour1,
        BlockDuration.day => s.day1,
        BlockDuration.week => s.week1,
        BlockDuration.custom => s.customTime,
      };

  IconData get icon => switch (this) {
        BlockDuration.hour => Icons.hourglass_bottom_rounded,
        BlockDuration.day => Icons.today_rounded,
        BlockDuration.week => Icons.date_range_rounded,
        BlockDuration.custom => Icons.edit_calendar_rounded,
      };

  /// Koniec blokovania pre pevné dĺžky (custom vráti null).
  DateTime? get fixedEnd {
    final now = DateTime.now();
    return switch (this) {
      BlockDuration.hour => now.add(const Duration(hours: 1)),
      BlockDuration.day => now.add(const Duration(days: 1)),
      BlockDuration.week => now.add(const Duration(days: 7)),
      BlockDuration.custom => null,
    };
  }
}

/// Výber vlastného konca – dátum a čas. Musí byť po [minEnd] (bežiace blokovanie sa dá iba predĺžiť).
Future<DateTime?> pickCustomEnd(BuildContext context, {DateTime? minEnd}) async {
  final s = S.of(context);
  final now = DateTime.now();
  final earliest = minEnd != null && minEnd.isAfter(now) ? minEnd : now;
  final date = await showDatePicker(
    context: context,
    initialDate: earliest,
    firstDate: DateTime(earliest.year, earliest.month, earliest.day),
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final suggested = earliest.add(const Duration(hours: 1));
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: suggested.hour, minute: suggested.minute),
  );
  if (time == null || !context.mounted) return null;
  final end = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (!end.isAfter(earliest.add(const Duration(minutes: 1)))) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(minEnd != null ? s.mustBeLonger(minEnd) : s.pickFuture)),
    );
    return null;
  }
  return end;
}

/// Spodný panel "Zablokovať na čas" pre položku alebo zoznam.
/// Ak už beží časové blokovanie do [currentEnd], ponúkne iba dlhšie možnosti.
/// Vráti koniec blokovania alebo null.
Future<DateTime?> showBlockForTimeSheet(
  BuildContext context, {
  required String name,
  DateTime? currentEnd,
}) async {
  final choice = await showModalBottomSheet<BlockDuration>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final s = S.of(context);
      final scheme = Theme.of(context).colorScheme;
      final bottom = MediaQuery.viewPaddingOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, bottom + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(currentEnd == null ? s.blockForTime : s.extendBlock,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                currentEnd == null ? name : '$name · ${s.onlyLonger(currentEnd)}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            for (final d in BlockDuration.values)
              Builder(builder: (context) {
                final end = d.fixedEnd;
                // Kratšie (alebo rovnako dlhé) než bežiace blokovanie sa nastaviť nedá.
                final tooShort = currentEnd != null && end != null && !end.isAfter(currentEnd);
                return ListTile(
                  enabled: !tooShort,
                  leading: Icon(d.icon),
                  title: Text(d.label(s), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: end == null ? null : Text(tooShort ? s.shorterThanCurrent : s.until(end)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onTap: () => Navigator.pop(context, d),
                );
              }),
          ],
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return null;
  return choice == BlockDuration.custom
      ? pickCustomEnd(context, minEnd: currentEnd)
      : choice.fixedEnd;
}

/// Potvrdenie pred spustením časového blokovania – po spustení sa nedá zrušiť.
Future<bool> confirmTimedBlock(
  BuildContext context, {
  required DateTime end,
  required int minutes,
  required int perDay,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      final s = S.of(context);
      return AlertDialog(
        icon: const Icon(Icons.lock_clock_rounded),
        title: Text(s.timedConfirmTitle),
        content: Text(s.timedConfirmBody(end, minutes, perDay)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.start)),
        ],
      );
    },
  );
  return ok == true;
}
