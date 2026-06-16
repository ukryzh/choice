import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/cycle_entry.dart';
import '../../models/symptom.dart';
import '../../services/onboarding/home_mini_tour.dart';
import '../legal/privacy_policy_screen.dart';
import '../../state/app_providers.dart';
import '../log_cycle/log_cycle_screen.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routeName = 'home';
  static const routePath = '/home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final GlobalKey _logPeriodsButtonKey = GlobalKey();
  final GlobalKey _symptomsSectionKey = GlobalKey();
  final GlobalKey _forecastButtonKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  bool _tourCheckInProgress = false;
  bool _tourAlreadyShownThisSession = false;
  bool _privacyCheckInProgress = false;
  bool _privacyDialogShownThisSession = false;

  @override
  Widget build(BuildContext context) {
    final cycleEntries = ref.watch(cycleEntriesProvider);

    // When data is successfully loaded the first time, schedule the tour.
    if (cycleEntries.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeShowPrivacyThenMiniTour();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cycle overview'),
        actions: [
          if (cycleEntries.hasValue)
            IconButton(
              key: _forecastButtonKey,
              icon: const Icon(Icons.calendar_month),
              onPressed: () => _showMonthCalendar(context, cycleEntries.value!),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(cycleEntriesProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: cycleEntries.when(
          data: (entries) => _buildContent(context, entries),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => EmptyState(
            title: 'Something went wrong',
            message: error.toString(),
            action: PrimaryButton(
              label: 'Retry',
              onPressed: () => ref.invalidate(cycleEntriesProvider),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(),
    );
  }

  Widget _buildContent(BuildContext context, List<CycleEntry> entries) {
    final loggedPastDays = _buildLoggedPastDays(entries);
    final loggedFutureDays = _buildLoggedFutureDays(entries);
    final symptomDays = _buildSymptomDays(entries);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final selectedDay = _selectedDay != null
        ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
        : normalizedToday;
    final entryForSelectedDay = _findEntryForDay(entries, selectedDay);
    final hasEntryForSelectedDay = entryForSelectedDay != null;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCalendar(
            loggedPastDays,
            loggedFutureDays,
            symptomDays,
            normalizedToday,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            key: _logPeriodsButtonKey,
            label: hasEntryForSelectedDay ? 'Edit data' : 'Log periods',
            expanded: true,
            onPressed: _canLogSelectedDay(normalizedToday)
                ? () => context.push(
                      LogCycleScreen.routePath,
                      // Если день не выбран, используем сегодняшнюю дату,
                      // чтобы диалог сразу был предзаполнен текущим днем.
                      extra: _selectedDay ?? normalizedToday,
                    )
                : null,
          ),
          const SizedBox(height: 24),
          Container(
            key: _symptomsSectionKey,
            child: Text(
              'Symptoms of the day',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          _buildSymptomsForSelectedDay(context, entryForSelectedDay),
          const SizedBox(height: 24),
          Text(
            'Cycle length',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _buildLineChart(entries),
          ),
        ],
      ),
    );
  }

  Future<void> _maybeStartMiniTourOnce() async {
    if (_tourAlreadyShownThisSession) return;
    if (_tourCheckInProgress) return;
    _tourCheckInProgress = true;
    try {
      final encryptedStorage = ref.read(encryptedStorageProvider);
      final Box<dynamic> box =
          await encryptedStorage.openEncryptedBox<dynamic>('app_settings');
      final seen = (box.get('home_mini_tour_seen') as bool?) ?? false;
      if (seen) return;

      // Ensure all targets are laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runMiniTourWithScroll(box);
      });
    } finally {
      _tourCheckInProgress = false;
    }
  }

  Future<void> _runMiniTourWithScroll(Box<dynamic> box) async {
    if (!mounted) return;
    if (_tourAlreadyShownThisSession) return;

    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    if (!mounted || _tourAlreadyShownThisSession) return;

    _tourAlreadyShownThisSession = true;
    final coach = HomeMiniTour.build(
      context: context,
      targets: HomeMiniTourTargets(
        logPeriodsButtonKey: _logPeriodsButtonKey,
        symptomsSectionKey: _symptomsSectionKey,
        forecastButtonKey: _forecastButtonKey,
      ),
      onSkip: () async {
        await box.put('home_mini_tour_seen', true);
      },
      onFinish: () async {
        await box.put('home_mini_tour_seen', true);
      },
    );

    coach.show(context: context);
  }

  Future<void> _maybeShowPrivacyThenMiniTour() async {
    if (!mounted) return;
    if (_privacyDialogShownThisSession) return;
    if (_privacyCheckInProgress) return;
    _privacyCheckInProgress = true;
    try {
      final encryptedStorage = ref.read(encryptedStorageProvider);
      final Box<dynamic> box =
          await encryptedStorage.openEncryptedBox<dynamic>('app_settings');

      final accepted = (box.get('privacy_policy_accepted') as bool?) ?? false;
      if (!accepted) {
        _privacyDialogShownThisSession = true;
        await _showPrivacyPolicyBlockingDialog(box);
      }

      if (!mounted) return;
      await _maybeStartMiniTourOnce();
    } finally {
      _privacyCheckInProgress = false;
    }
  }

  Future<void> _showPrivacyPolicyBlockingDialog(Box<dynamic> box) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    const Expanded(
                      child: PrivacyPolicyContent(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await box.put('privacy_policy_accepted', true);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          },
                          child: const Text('Accept'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendar(
    Map<DateTime, bool> pastLogs,
    Map<DateTime, bool> futureLogs,
    Map<DateTime, bool> symptomDays,
    DateTime today,
  ) {
    const lightPink = Color(0xFFFFA9B9);
    const selectedPink = Color(0xFFFF6081);

    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: _focusedDay,
      rowHeight: 48,
      daysOfWeekHeight: 28,
      eventLoader: (day) {
        final normalized = DateTime(day.year, day.month, day.day);
        final hasSymptoms = symptomDays[normalized] ?? false;
        if (!hasSymptoms) return const [];
        return const ['symptom'];
      },
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
        ),
        todayTextStyle: const TextStyle(color: Colors.black),
        selectedDecoration: const BoxDecoration(
          color: selectedPink,
          shape: BoxShape.circle,
        ),
        markersAlignment: Alignment.bottomCenter,
        markersMaxCount: 4,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) =>
            _buildDayCell(day, pastLogs, futureLogs, today, lightPink: lightPink),
        outsideBuilder: (context, day, focusedDay) =>
            _buildDayCell(day, pastLogs, futureLogs, today,
                lightPink: lightPink, isOutside: true),
        todayBuilder: (context, day, focusedDay) => _buildDayCell(
          day,
          pastLogs,
          futureLogs,
          today,
          lightPink: lightPink,
          isToday: true,
        ),
        selectedBuilder: (context, day, focusedDay) => _buildDayCell(
          day,
          pastLogs,
          futureLogs,
          today,
          lightPink: lightPink,
          selectedColor: selectedPink,
          isSelected: true,
        ),
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return const SizedBox.shrink();
          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }

  Map<DateTime, bool> _buildLoggedPastDays(List<CycleEntry> entries) {
    final map = <DateTime, bool>{};
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    for (final entry in entries) {
      for (final day in _daysInRange(entry.cycleStart, entry.cycleEnd)) {
        final normalized = DateTime(day.year, day.month, day.day);
        if (normalized.isBefore(normalizedToday)) {
          map[normalized] = true;
        }
      }
    }
    return map;
  }

  bool _canLogSelectedDay(DateTime today) {
    if (_selectedDay == null) return true;
    final selected = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    return !selected.isAfter(today);
  }

  Map<DateTime, bool> _buildLoggedFutureDays(List<CycleEntry> entries) {
    final map = <DateTime, bool>{};
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    for (final entry in entries) {
      for (final day in _daysInRange(entry.cycleStart, entry.cycleEnd)) {
        final normalized = DateTime(day.year, day.month, day.day);
        if (normalized.isAfter(normalizedToday)) {
          map[normalized] = true;
        }
      }
    }
    return map;
  }

  Map<DateTime, bool> _buildSymptomDays(List<CycleEntry> entries) {
    final map = <DateTime, bool>{};
    for (final entry in entries) {
      if (entry.symptoms.isEmpty) continue;
      for (final day in _daysInRange(entry.cycleStart, entry.cycleEnd)) {
        final normalized = DateTime(day.year, day.month, day.day);
        map[normalized] = true;
      }
    }
    return map;
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
    final intervals = <int>[];
    for (var i = starts.length - 1; i > 0 && intervals.length < 6; i--) {
      final diff = starts[i].difference(starts[i - 1]).inDays;
      if (diff > 0) intervals.add(diff);
    }
    if (intervals.isEmpty) return {};
    final avg = intervals.reduce((a, b) => a + b) / intervals.length;
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

  List<DateTime> _extractCycleStarts(List<CycleEntry> entries) {
    if (entries.isEmpty) return [];
    
    // Sort entries by cycleStart
    final sortedEntries = List<CycleEntry>.from(entries)
      ..sort((a, b) => a.cycleStart.compareTo(b.cycleStart));
    
    final starts = <DateTime>[];
    CycleEntry? prevEntry;
    
    for (final entry in sortedEntries) {
      final entryStart = DateTime(
        entry.cycleStart.year,
        entry.cycleStart.month,
        entry.cycleStart.day,
      );
      final entryEnd = DateTime(
        entry.cycleEnd.year,
        entry.cycleEnd.month,
        entry.cycleEnd.day,
      );
      
      if (prevEntry == null) {
        // First entry - always add as new cycle start
        starts.add(entryStart);
      } else {
        final prevEnd = DateTime(
          prevEntry.cycleEnd.year,
          prevEntry.cycleEnd.month,
          prevEntry.cycleEnd.day,
        );
        
        // Calculate days between end of previous cycle and start of current cycle
        // If prevEnd is Dec 16 and entryStart is Dec 17, difference is 1 day (they are consecutive)
        final daysBetween = entryStart.difference(prevEnd).inDays;
        
        // If more than 2 days gap, this is a new cycle
        // If 2 days or less gap (including consecutive days), this is continuation
        if (daysBetween > 2) {
          starts.add(entryStart);
        }
        // If 2 days or less, this is continuation of previous cycle - don't add new start
      }
      
      prevEntry = entry;
    }
    
    return starts;
  }

  CycleEntry? _findEntryForDay(List<CycleEntry> entries, DateTime day) {
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

  Widget _buildDayCell(
    DateTime day,
    Map<DateTime, bool> pastLogs,
    Map<DateTime, bool> futureLogs,
    DateTime today, {
    required Color lightPink,
    Color? selectedColor,
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final normalized = DateTime(day.year, day.month, day.day);
    final isPastLogged = pastLogs.containsKey(normalized);
    final isFutureLogged = futureLogs.containsKey(normalized);

    BoxDecoration? decoration;
    TextStyle? textStyle;

    if (isSelected) {
      decoration = BoxDecoration(
        color: selectedColor ?? lightPink,
        shape: BoxShape.circle,
      );
      textStyle = const TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
    } else if (isToday) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      );
    } else if (isPastLogged) {
      decoration = BoxDecoration(
        color: lightPink,
        shape: BoxShape.circle,
      );
    } else if (isFutureLogged) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: lightPink, width: 2),
      );
    }

    final hasLog = isPastLogged || isFutureLogged;

    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: decoration,
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: textStyle ??
              TextStyle(
                color: isOutside ? Colors.grey : Colors.black,
                fontWeight: hasLog ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }

  Widget _buildSymptomsForSelectedDay(BuildContext context, CycleEntry? entry) {
    if (entry == null || entry.symptoms.isEmpty) {
      return Text(
        'There are no symptoms for the day. Press "Log periods" to log your symptoms',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return _buildSymptomStrip(context, entry.symptoms);
  }

  Widget _buildSymptomStrip(BuildContext context, List<SymptomLog> symptoms) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: symptoms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final symptom = symptoms[index];
          return Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                child: Text(
                  symptom.type.label.characters.first.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                symptom.type.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLineChart(List<CycleEntry> entries) {
    final chartData = _buildCycleChartData(entries);
    final points = chartData.values;
    final spots = points.indexed
        .map((entry) => FlSpot(entry.$1.toDouble(), entry.$2.toDouble()))
        .toList();
    final maxY = spots.isEmpty ? 10 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxX = spots.isEmpty ? 0 : spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
    final minX = -0.25;

    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 10,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                final isInteger = (value - index).abs() < 0.01;
                if (!isInteger || index < 0 || index >= chartData.labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(chartData.labels[index]);
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            color: const Color(0xFFFF6081),
            isCurved: true,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0x33FFA9B9),
            ),
            spots: spots,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => _DotWithLabelPainter(
                color: const Color(0xFFFF6081),
                radius: 4,
                label: spot.y.toInt().toString(),
                textStyle: const TextStyle(fontSize: 10, color: Colors.black),
              ),
            ),
          ),
        ],
        minY: 0,
        maxY: maxY + 2,
        minX: minX,
        maxX: maxX + 0.25,
      ),
    );
  }

  _CycleChartData _buildCycleChartData(List<CycleEntry> entries) {
    if (entries.isEmpty) return const _CycleChartData([], []);

    final today = DateTime.now();
    final sixMonthsAgo =
        DateTime(today.year, today.month, today.day).subtract(const Duration(days: 183));

    // Use the same logic as _extractCycleStarts to group cycles
    final sortedEntries = entries
        .where((e) {
          final start = DateTime(e.cycleStart.year, e.cycleStart.month, e.cycleStart.day);
          return !start.isBefore(sixMonthsAgo);
        })
        .toList()
      ..sort((a, b) => a.cycleStart.compareTo(b.cycleStart));

    final starts = <DateTime>[];
    CycleEntry? prevEntry;
    
    for (final entry in sortedEntries) {
      final entryStart = DateTime(
        entry.cycleStart.year,
        entry.cycleStart.month,
        entry.cycleStart.day,
      );
      
      if (prevEntry == null) {
        starts.add(entryStart);
      } else {
        final prevEnd = DateTime(
          prevEntry.cycleEnd.year,
          prevEntry.cycleEnd.month,
          prevEntry.cycleEnd.day,
        );
        final daysBetween = entryStart.difference(prevEnd).inDays;
        if (daysBetween > 2) {
          starts.add(entryStart);
        }
      }
      prevEntry = entry;
    }

    if (starts.length < 1) return const _CycleChartData([], []);

    final labels = <String>[];
    final values = <double>[];

    // First start is x=0 with value 0 (no prior cycle in range).
    labels.add(DateFormat('MMM d').format(starts.first));
    values.add(0);

    for (var i = 1; i < starts.length; i++) {
      final prevStart = starts[i - 1];
      final currentStart = starts[i];
      final isLastPoint = i == starts.length - 1;
      final endPoint = isLastPoint ? today : currentStart;
      final diff = endPoint.difference(prevStart).inDays;
      if (diff <= 0) continue;
      final label = DateFormat('MMM d').format(currentStart);
      labels.add(label);
      values.add(diff.toDouble());
    }

    return _CycleChartData(labels, values);
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
            return SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Text(
                      'The forecast is for reference only and cannot be used for treatment or other medical purposes.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.75),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
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
                    ),
                  ),
                ],
              ),
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
}

class _CycleChartData {
  const _CycleChartData(this.labels, this.values);

  final List<String> labels;
  final List<double> values;
}

class _DotWithLabelPainter extends FlDotPainter {
  const _DotWithLabelPainter({
    required this.color,
    required this.radius,
    required this.label,
    required this.textStyle,
  });

  final Color color;
  final double radius;
  final String label;
  final TextStyle textStyle;

  @override
  Color get mainColor => color;

  @override
  List<Object?> get props => [color, radius, label, textStyle];

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => this;

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final paint = Paint()..color = color;
    canvas.drawCircle(offsetInCanvas, radius, paint);

    final tp = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final textOffset = offsetInCanvas - Offset(tp.width / 2, tp.height / 2);
    final bgRect = Rect.fromLTWH(
      textOffset.dx - 4,
      textOffset.dy - 2,
      tp.width + 8,
      tp.height + 4,
    );
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      bgPaint,
    );
    final borderPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      borderPaint,
    );

    tp.paint(canvas, textOffset);
  }

  @override
  Size getSize(FlSpot spot) => Size(radius * 2, radius * 2);

  @override
  FlDotPainter copyWith({
    Color? color,
    double? strokeWidth,
    Color? strokeColor,
  }) {
    return _DotWithLabelPainter(
      color: color ?? this.color,
      radius: radius,
      label: label,
      textStyle: textStyle,
    );
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
    final firstWeekday = days.first.weekday % 7;
    // Всегда 6 строк, фиксированная высота
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
    return List.generate(next.difference(first).inDays, (i) => DateTime(year, month, i + 1));
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.actual, required this.predicted});

  final DateTime day;
  final bool actual;
  final bool predicted;

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFFA9B9);
    BoxDecoration? decoration;
    if (actual) {
      decoration = const BoxDecoration(color: pink, shape: BoxShape.circle);
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


