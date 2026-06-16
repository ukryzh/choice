import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/symptom_catalog.dart';
import '../../models/cycle_entry.dart';
import '../../models/symptom.dart';
import '../../state/app_providers.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/symptom_chip.dart';

class LogCycleScreen extends ConsumerStatefulWidget {
  const LogCycleScreen({super.key, this.initialDay});

  /// When navigating from the calendar we prefill the range with the tapped day
  /// so the save button is enabled without extra input.
  final DateTime? initialDay;

  static const routeName = 'log-cycle';
  static const routePath = '/log-cycle';

  @override
  ConsumerState<LogCycleScreen> createState() => _LogCycleScreenState();
}

class _LogCycleScreenState extends ConsumerState<LogCycleScreen> {
  DateTimeRange? _range;
  bool _rangeEdited = false;
  final Map<SymptomType, SymptomIntensity> _symptoms = {};
  CycleEntry? _existingEntry;
  bool _prefilledFromExisting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDay != null) {
      final day = widget.initialDay!;
      _range = DateTimeRange(start: day, end: day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(cycleEntriesProvider);
    if (!_prefilledFromExisting && widget.initialDay != null && entries.hasValue) {
      final match = _findExactEntryForDay(entries.value!, widget.initialDay!);
      if (match != null) {
        _prefillFromEntry(match);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log period'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              final entries = ref.read(cycleEntriesProvider).valueOrNull ?? [];
              _showMonthCalendar(context, entries);
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Period dates'),
                subtitle: Text(
                  _range == null
                      ? 'Select the days of your last period'
                      : '${_formatDate(_range!.start)} → ${_formatDate(_range!.end)}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final initialRange = _range != null && !_range!.end.isAfter(today)
                        ? _range
                        : DateTimeRange(start: today, end: today);
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 1),
                      lastDate: today,
                      initialDateRange: initialRange,
                    );
                    if (range != null) {
                      setState(() {
                        _range = range;
                        _rangeEdited = true;
                      });
                    }
                  },
                  child: const Text('Date Range'),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Symptoms',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: SymptomCatalog.entries
                    .map(
                      (symptom) => SymptomChip(
                        symptom: symptom,
                        selected: _symptoms[symptom] ?? SymptomIntensity.none,
                        onTap: () => setState(() {
                          final current = _symptoms[symptom] ?? SymptomIntensity.none;
                          // Single tap toggles selected <-> none
                          if (current == SymptomIntensity.none) {
                            _symptoms[symptom] = SymptomIntensity.mild;
                          } else {
                            _symptoms.remove(symptom);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _range == null ? null : _confirmClearAll,
                      child: const Text('Clear all'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Save',
                      expanded: true,
                      onPressed: _range == null ? null : _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final baseRange = _range!;
    final entries = ref.read(cycleEntriesProvider).valueOrNull ?? [];
    
    // Check if the selected day continues an existing cycle
    final selectedStart = DateTime(
      baseRange.start.year,
      baseRange.start.month,
      baseRange.start.day,
    );
    
    bool continuesExistingCycle = false;
    for (final entry in entries) {
      final entryEnd = DateTime(
        entry.cycleEnd.year,
        entry.cycleEnd.month,
        entry.cycleEnd.day,
      );
      final daysBetween = selectedStart.difference(entryEnd).inDays;
      if (daysBetween >= 0 && daysBetween <= 2) {
        continuesExistingCycle = true;
        break;
      }
    }
    
    // Only auto-add 4 days if this is a new cycle, not a continuation
    final targetRange = (!_rangeEdited && baseRange.start.isAtSameMomentAs(baseRange.end) && !continuesExistingCycle)
        ? DateTimeRange(start: baseRange.start, end: baseRange.start.add(const Duration(days: 4)))
        : baseRange;

    final normalizedSymptomDay =
        DateTime(targetRange.start.year, targetRange.start.month, targetRange.start.day);
    final days = _daysInRange(targetRange.start, targetRange.end)
        .map((d) => DateTime(d.year, d.month, d.day))
        .toList();
    final symptoms = _symptoms.entries
        .where((entry) => entry.value != SymptomIntensity.none)
        .map(
          (entry) => SymptomLog(
            type: entry.key,
            intensity: entry.value,
          ),
        )
        .toList();

    final notifier = ref.read(cycleEntriesProvider.notifier);

    // Save days as usual - the grouping logic in _extractCycleStarts will handle
    // merging cycles that are within 2 days of each other
    for (final day in days) {
      final isSymptomDay = day.year == normalizedSymptomDay.year &&
          day.month == normalizedSymptomDay.month &&
          day.day == normalizedSymptomDay.day;
      final entrySymptoms = isSymptomDay ? symptoms : <SymptomLog>[];
      final existing = _findExactEntryForDay(entries, day);
      final entry = CycleEntry(
        id: existing?.id,
        cycleStart: day,
        cycleEnd: day,
        symptoms: entrySymptoms,
        createdAt: existing?.createdAt,
      );
      await notifier.addEntry(entry);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cycle saved locally 🎉')),
      );
      context.pop();
    }
  }

  SymptomIntensity _nextIntensity(SymptomIntensity current) {
    switch (current) {
      case SymptomIntensity.none:
        return SymptomIntensity.mild;
      case SymptomIntensity.mild:
        return SymptomIntensity.moderate;
      case SymptomIntensity.moderate:
        return SymptomIntensity.severe;
      case SymptomIntensity.severe:
        return SymptomIntensity.none;
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear selected range?'),
        content: const Text(
          'All data about your periods and symptoms will be deleted for the selected days. '
          'Are you sure, you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearAll();
    }
  }

  Future<void> _clearAll() async {
    final entries = ref.read(cycleEntriesProvider).valueOrNull;
    final range = _range;
    if (entries != null && range != null) {
      final notifier = ref.read(cycleEntriesProvider.notifier);
      final targets = _daysInRange(range.start, range.end)
          .map((d) => DateTime(d.year, d.month, d.day))
          .toSet();
      for (final entry in entries) {
        final start = DateTime(entry.cycleStart.year, entry.cycleStart.month, entry.cycleStart.day);
        final end = DateTime(entry.cycleEnd.year, entry.cycleEnd.month, entry.cycleEnd.day);
        final intersects = targets.any((day) => !day.isBefore(start) && !day.isAfter(end));
        if (intersects) {
          await notifier.deleteEntry(entry.id);
        }
      }
    }

    if (context.mounted) {
      context.pop();
    }
  }

  CycleEntry? _findExactEntryForDay(List<CycleEntry> entries, DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    for (final entry in entries) {
      final start = DateTime(entry.cycleStart.year, entry.cycleStart.month, entry.cycleStart.day);
      final end = DateTime(entry.cycleEnd.year, entry.cycleEnd.month, entry.cycleEnd.day);
      if (normalized.isAtSameMomentAs(start) && normalized.isAtSameMomentAs(end)) {
        return entry;
      }
    }
    return null;
  }

  CycleEntry? _findEntryContainingDay(List<CycleEntry> entries, DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    for (final entry in entries) {
      final start = DateTime(entry.cycleStart.year, entry.cycleStart.month, entry.cycleStart.day);
      final end = DateTime(entry.cycleEnd.year, entry.cycleEnd.month, entry.cycleEnd.day);
      if (!normalized.isBefore(start) && !normalized.isAfter(end)) {
        return entry;
      }
    }
    return null;
  }

  Iterable<DateTime> _daysInRange(DateTime start, DateTime end) sync* {
    var current = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!current.isAfter(last)) {
      yield current;
      current = current.add(const Duration(days: 1));
    }
  }

  void _prefillFromEntry(CycleEntry entry) {
    if (_prefilledFromExisting) return;
    _prefilledFromExisting = true;
    final mappedSymptoms = <SymptomType, SymptomIntensity>{};
    for (final symptom in entry.symptoms) {
      mappedSymptoms[symptom.type] = symptom.intensity;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _existingEntry = entry;
        _range = DateTimeRange(start: entry.cycleStart, end: entry.cycleEnd);
        _rangeEdited = true;
        _symptoms
          ..clear()
          ..addAll(mappedSymptoms);
      });
    });
  }

  void _showMonthCalendar(BuildContext context, List<CycleEntry> entries) {
    final actualDays = _buildActualDays(entries);
    final predictedDays = _buildPredictedDays(entries);
    final today = DateTime.now();
    final months = _buildMonthRange(entries);
    final currentMonth = DateTime(today.year, today.month, 1);
    final currentIndex = months.indexWhere(
      (m) => m.year == currentMonth.year && m.month == currentMonth.month,
    );
    final heights = months.map(_monthHeight).toList();
    final initialOffset =
        currentIndex > 0 ? heights.take(currentIndex).fold<double>(0, (a, b) => a + b) : 0.0;
    final controller = ScrollController(initialScrollOffset: initialOffset);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, sheetController) {
            return ListView.builder(
              controller: controller,
              itemCount: months.length,
              itemBuilder: (context, index) {
                final month = months[index];
                final height = heights[index];
                return SizedBox(
                  height: height,
                  child: _MonthView(
                    month: month,
                    actualDays: actualDays,
                    predictedDays: predictedDays,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<DateTime> _buildMonthRange(List<CycleEntry> entries) {
    final today = DateTime.now();
    final currentMonth = DateTime(today.year, today.month, 1);
    DateTime start = currentMonth;
    if (entries.isNotEmpty) {
      final first = entries
          .map((e) => DateTime(e.cycleStart.year, e.cycleStart.month, 1))
          .reduce((a, b) => a.isBefore(b) ? a : b);
      start = first.isBefore(currentMonth) ? first : currentMonth;
    }
    final end = DateTime(currentMonth.year, currentMonth.month + 12, 1);
    final months = <DateTime>[];
    var cursor = DateTime(start.year, start.month, 1);
    while (!cursor.isAfter(end)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return months;
  }

  Set<DateTime> _buildActualDays(List<CycleEntry> entries) {
    final set = <DateTime>{};
    for (final entry in entries) {
      for (final day in _daysInRange(entry.cycleStart, entry.cycleEnd)) {
        set.add(DateTime(day.year, day.month, day.day));
      }
    }
    return set;
  }

  Set<DateTime> _buildPredictedDays(List<CycleEntry> entries) {
    final starts = _extractCycleStarts(entries);
    if (starts.length < 2) return {};
    final lastIntervals = <int>[];
    for (var i = starts.length - 1; i > 0 && lastIntervals.length < 6; i--) {
      final diff = starts[i].difference(starts[i - 1]).inDays;
      if (diff > 0) lastIntervals.add(diff);
    }
    if (lastIntervals.isEmpty) return {};
    final avg = lastIntervals.reduce((a, b) => a + b) / lastIntervals.length;
    final cycleLen = avg.round().clamp(15, 60);
    final set = <DateTime>{};
    final today = DateTime.now();
    final horizon = DateTime(today.year, today.month + 12, today.day);
    var nextStart = starts.last.add(Duration(days: cycleLen));
    while (!nextStart.isAfter(horizon)) {
      if (nextStart.isAfter(today)) {
        for (int d = 0; d < 5; d++) {
          set.add(DateTime(nextStart.year, nextStart.month, nextStart.day + d));
        }
      }
      nextStart = nextStart.add(Duration(days: cycleLen));
    }
    return set;
  }

  double _monthHeight(DateTime month) {
    const rows = 6;
    const cellSize = 40.0;
    const spacing = 6.0;
    final gridHeight = rows * cellSize + (rows - 1) * spacing;
    const headerHeight = 32.0; // text + spacing
    const padding = 16.0; // vertical padding total
    return gridHeight + headerHeight + padding;
  }

  List<DateTime> _daysOfMonthLocal(int year, int month) {
    final first = DateTime(year, month, 1);
    final next = DateTime(year, month + 1, 1);
    return List.generate(next.difference(first).inDays, (i) => DateTime(year, month, i + 1));
  }

  List<DateTime> _extractCycleStarts(List<CycleEntry> entries) {
    final days = entries
        .map((e) => DateTime(e.cycleStart.year, e.cycleStart.month, e.cycleStart.day))
        .toList()
      ..sort();
    final starts = <DateTime>[];
    DateTime? prev;
    for (final day in days) {
      if (prev == null || day.difference(prev).inDays > 1) {
        starts.add(day);
      }
      prev = day;
    }
    return starts;
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.actualDays,
    required this.predictedDays,
  });

  final DateTime month;
  final Set<DateTime> actualDays;
  final Set<DateTime> predictedDays;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM yyyy');
    final days = _daysOfMonth(month.year, month.month);
    final firstWeekday = days.first.weekday % 7; // 0..6, where 0=Sunday
    // Всегда рисуем 6 строк, чтобы сетка не меняла высоту
    const rows = 6;
    final paddedCells = rows * 7;
    // Фиксированная высота для 6 строк
    const cellHeight = 40.0;
    const spacing = 6.0;
    final gridHeight = rows * cellHeight + (rows - 1) * spacing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatter.format(month), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: gridHeight,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 1,
              ),
              itemCount: paddedCells,
              itemBuilder: (context, index) {
                if (index < firstWeekday || index - firstWeekday >= days.length) {
                  return const SizedBox.shrink();
                }
                final day = days[index - firstWeekday];
                final isActual = actualDays.contains(day);
                final isPredicted = predictedDays.contains(day) && !isActual;
                return _DayCell(day: day, actual: isActual, predicted: isPredicted);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime> _daysOfMonth(int year, int month) {
    final first = DateTime(year, month, 1);
    final next = DateTime(year, month + 1, 1);
    return List.generate(
      next.difference(first).inDays,
      (i) => DateTime(year, month, i + 1),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.actual, required this.predicted});

  final DateTime day;
  final bool actual;
  final bool predicted;

  @override
  Widget build(BuildContext context) {
    final pink = const Color(0xFFFFA9B9);
    BoxDecoration? decoration;
    if (actual) {
      decoration = BoxDecoration(color: pink, shape: BoxShape.circle);
    } else if (predicted) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: pink, width: 2),
      );
    }
    return Center(
      child: Container(
        width: 32,
        height: 32,
        decoration: decoration,
        alignment: Alignment.center,
        child: Text('${day.day}'),
      ),
    );
  }
}


