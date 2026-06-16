import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace_preference.dart';
import '../../state/app_providers.dart';
import '../../state/marketplace_notifier.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';

class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  static const routeName = 'marketplace';
  static const routePath = '/marketplace';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(marketplacePreferencesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(marketplacePreferencesProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          data: (data) => const _MarketplaceBody(),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            title: 'Marketplace unavailable',
            message: error.toString(),
            action: PrimaryButton(
              label: 'Retry',
              onPressed: () => ref.invalidate(marketplacePreferencesProvider),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(),
    );
  }
}

class _MarketplaceBody extends ConsumerStatefulWidget {
  const _MarketplaceBody();

  @override
  ConsumerState<_MarketplaceBody> createState() => _MarketplaceBodyState();
}

class _MarketplaceBodyState extends ConsumerState<_MarketplaceBody> {
  final Map<String, bool> _expanded = {};
  bool _hasChanges = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketplacePreferencesProvider);
    final stateValue = state.valueOrNull;
    if (stateValue == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final merged = _mergePreferences(
      stateValue.availableOffers,
      stateValue.preferences,
    );
    final categories = _buildCategories(merged);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ...categories.map((category) => _buildCategoryCard(context, category)),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Save my choice',
          onPressed: _hasChanges
              ? () {
                  setState(() {
                    _hasChanges = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your choice was saved. You can change it any time'),
                    ),
                  );
                }
              : null,
          expanded: true,
        ),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, _Category category) {
    final notifier = ref.read(marketplacePreferencesProvider.notifier);
    final allHaveCycle = category.buyers.isNotEmpty &&
        category.buyers.every((b) => b.selectedScopes.contains(DataShareScope.cycleStats));
    final allHaveSymptoms = category.buyers.isNotEmpty &&
        category.buyers.every((b) => b.selectedScopes.contains(DataShareScope.anonymizedSymptoms));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            title: Text(category.title),
            trailing: Icon(
              _expanded[category.title] == true ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                _expanded[category.title] = !(_expanded[category.title] ?? false);
              });
            },
            subtitle: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  key: ValueKey('${category.title}_cycle_$allHaveCycle'),
                  label: const Text('Cycle dates'),
                  selected: allHaveCycle,
                  onSelected: (_) async {
                    await _setScopeForCategory(
                      category,
                      DataShareScope.cycleStats,
                      !allHaveCycle,
                    );
                  },
                ),
                FilterChip(
                  key: ValueKey('${category.title}_symptoms_$allHaveSymptoms'),
                  label: const Text('Symptoms'),
                  selected: allHaveSymptoms,
                  onSelected: (_) async {
                    await _setScopeForCategory(
                      category,
                      DataShareScope.anonymizedSymptoms,
                      !allHaveSymptoms,
                    );
                  },
                ),
              ],
            ),
          ),
          if (_expanded[category.title] == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: category.buyers
                    .map(
                      (buyer) => CheckboxListTile(
                        key: ValueKey('${buyer.organization}_${buyer.selectedScopes.hashCode}'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: buyer.selectedScopes.isNotEmpty,
                        title: Text(buyer.organization),
                        subtitle: Wrap(
                          spacing: 8,
                          children: [
                            FilterChip(
                              key: ValueKey('${buyer.organization}_cycle_${buyer.selectedScopes.contains(DataShareScope.cycleStats)}'),
                              label: const Text('Cycle dates'),
                              selected: buyer.selectedScopes.contains(DataShareScope.cycleStats),
                              onSelected: (selected) async {
                                await _toggleScopeForBuyer(
                                  buyer,
                                  DataShareScope.cycleStats,
                                  selected,
                                );
                              },
                            ),
                            FilterChip(
                              key: ValueKey('${buyer.organization}_symptoms_${buyer.selectedScopes.contains(DataShareScope.anonymizedSymptoms)}'),
                              label: const Text('Symptoms'),
                              selected:
                                  buyer.selectedScopes.contains(DataShareScope.anonymizedSymptoms),
                              onSelected: (selected) async {
                                await _toggleScopeForBuyer(
                                  buyer,
                                  DataShareScope.anonymizedSymptoms,
                                  selected,
                                );
                              },
                            ),
                          ],
                        ),
                        onChanged: (checked) async {
                          if (checked == null) return;
                          final stateValue = ref.read(marketplacePreferencesProvider).valueOrNull;
                          if (stateValue == null) return;
                          
                          // Get fresh merged preferences to ensure we have the latest state
                          final merged = _mergePreferences(
                            stateValue.availableOffers,
                            stateValue.preferences,
                          );
                          final latestBuyer = merged.firstWhere(
                            (p) => p.organization == buyer.organization,
                            orElse: () => buyer,
                          );
                          
                          final scopes =
                              checked == true ? {DataShareScope.cycleStats} : <DataShareScope>{};
                          await notifier.setScopes(preference: latestBuyer, scopes: scopes);
                          if (mounted) {
                            setState(() {
                              _hasChanges = true;
                            });
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setScopeForCategory(
    _Category category,
    DataShareScope scope,
    bool add,
  ) async {
    final notifier = ref.read(marketplacePreferencesProvider.notifier);
    final stateValue = ref.read(marketplacePreferencesProvider).valueOrNull;
    if (stateValue == null) return;
    
    // Get fresh merged preferences to ensure we have the latest state
    final merged = _mergePreferences(
      stateValue.availableOffers,
      stateValue.preferences,
    );
    final mergedMap = {for (var p in merged) p.organization: p};
    
    for (final buyer in category.buyers) {
      // Get the latest buyer object from merged preferences
      final latestBuyer = mergedMap[buyer.organization] ?? buyer;
      final current = {...latestBuyer.selectedScopes};
      if (add) {
        current.add(scope);
      } else {
        current.remove(scope);
      }
      await notifier.setScopes(preference: latestBuyer, scopes: current);
    }
    if (mounted) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _toggleScopeForBuyer(
    MarketplacePreference buyer,
    DataShareScope scope,
    bool add,
  ) async {
    final notifier = ref.read(marketplacePreferencesProvider.notifier);
    final stateValue = ref.read(marketplacePreferencesProvider).valueOrNull;
    if (stateValue == null) return;
    
    // Get fresh merged preferences to ensure we have the latest state
    final merged = _mergePreferences(
      stateValue.availableOffers,
      stateValue.preferences,
    );
    final latestBuyer = merged.firstWhere(
      (p) => p.organization == buyer.organization,
      orElse: () => buyer,
    );
    
    final current = {...latestBuyer.selectedScopes};
    if (add) {
      current.add(scope);
    } else {
      current.remove(scope);
    }
    await notifier.setScopes(preference: latestBuyer, scopes: current);
    if (mounted) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  List<MarketplacePreference> _mergePreferences(
    List<MarketplacePreference> offers,
    List<MarketplacePreference> saved,
  ) {
    final map = <String, MarketplacePreference>{};
    // First, add all offers as base
    for (final offer in offers) {
      map[offer.organization] = offer;
    }
    // Then, override with saved preferences (which have the latest state)
    for (final pref in saved) {
      map[pref.organization] = pref;
    }
    // Return a new list to ensure we're not using stale references
    return List<MarketplacePreference>.from(map.values);
  }

  List<_Category> _buildCategories(List<MarketplacePreference> prefs) {
    const titles = [
      'Medical research',
      'Marketing research',
      'Other',
    ];
    final buckets = List.generate(3, (_) => <MarketplacePreference>[]);
    for (final pref in prefs) {
      if (pref.organization.toLowerCase().contains('research')) {
        buckets[0].add(pref);
      } else if (pref.organization.toLowerCase().contains('marketing')) {
        buckets[1].add(pref);
      } else {
        buckets[2].add(pref);
      }
    }
    return List.generate(
      3,
      (index) => _Category(title: titles[index], buyers: buckets[index]),
    );
  }
}

class _Category {
  _Category({required this.title, required this.buyers});

  final String title;
  final List<MarketplacePreference> buyers;
}


