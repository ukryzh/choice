import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cycle_entry.dart';
import 'app_providers.dart';

class CycleEntriesNotifier extends AsyncNotifier<List<CycleEntry>> {
  @override
  Future<List<CycleEntry>> build() async {
    final repository = ref.watch(cycleRepositoryProvider);
    return repository.fetchEntries();
  }

  Future<void> addEntry(CycleEntry entry) async {
    final repository = ref.read(cycleRepositoryProvider);
    await repository.upsertEntry(entry);
    state = await AsyncValue.guard(() => repository.fetchEntries());
  }

  Future<void> deleteEntry(String id) async {
    final repository = ref.read(cycleRepositoryProvider);
    await repository.deleteEntry(id);
    state = await AsyncValue.guard(() => repository.fetchEntries());
  }

  /// Clear all cycle entries (used when user deletes local Calendar data).
  Future<void> clearAll() async {
    final repository = ref.read(cycleRepositoryProvider);
    await repository.clearAllEntries();
    // Обновляем состояние, чтобы календарь сразу перестроился без отмеченных дней
    state = const AsyncValue.data(<CycleEntry>[]);
  }

  /// Replace all existing entries with provided list.
  Future<void> replaceAll(List<CycleEntry> entries) async {
    final repository = ref.read(cycleRepositoryProvider);
    await repository.replaceAllEntries(entries);
    state = await AsyncValue.guard(() => repository.fetchEntries());
  }
}


