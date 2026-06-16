import '../../models/marketplace_preference.dart';

/// Placeholder for the future marketplace backend integration.
class MarketplaceApi {
  Future<List<MarketplacePreference>> fetchAvailableOffers() async {
    // Replace with real HTTP call once backend exists.
    return const [
      MarketplacePreference(organization: 'Global Cycle Research'),
      MarketplacePreference(organization: 'Women\'s Health NGO'),
      MarketplacePreference(organization: 'Lifestyle Insights Lab'),
    ];
  }

  Future<void> submitPreference(MarketplacePreference preference) async {
    // Real implementation will hit remote API.
  }
}


