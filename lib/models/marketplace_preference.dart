import 'dart:convert';

import 'package:equatable/equatable.dart';

enum DataShareScope { cycleStats, anonymizedSymptoms, lifestyle }

class MarketplacePreference extends Equatable {
  const MarketplacePreference({
    required this.organization,
    this.selectedScopes = const {DataShareScope.cycleStats},
    this.tokenReward = 0,
  });

  factory MarketplacePreference.fromJson(Map<String, dynamic> json) {
    final scopes = (json['scopes'] as List<dynamic>? ?? [])
        .map(
          (scope) => DataShareScope.values.firstWhere(
            (element) => element.name == scope,
            orElse: () => DataShareScope.cycleStats,
          ),
        )
        .toSet();
    return MarketplacePreference(
      organization: json['organization'] as String,
      selectedScopes: scopes,
      tokenReward: json['tokenReward'] as int? ?? 0,
    );
  }

  final String organization;
  final Set<DataShareScope> selectedScopes;
  final int tokenReward;

  MarketplacePreference copyWith({
    Set<DataShareScope>? selectedScopes,
    int? tokenReward,
  }) {
    return MarketplacePreference(
      organization: organization,
      selectedScopes: selectedScopes ?? this.selectedScopes,
      tokenReward: tokenReward ?? this.tokenReward,
    );
  }

  Map<String, dynamic> toJson() => {
        'organization': organization,
        'scopes': selectedScopes.map((scope) => scope.name).toList(),
        'tokenReward': tokenReward,
      };

  String encode() => jsonEncode(toJson());

  @override
  List<Object?> get props => [organization, selectedScopes, tokenReward];
}

