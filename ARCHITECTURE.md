# choice – Privacy-Preserving Cycle Tracker

## Project layout

```
lib/
  app_router.dart          // go_router definitions
  main.dart                // ProviderScope bootstrapping + Hive init
  data/                    // Static catalogs (symptoms, mock orgs)
  models/                  // Entities (cycles, symptoms, user, marketplace)
  screens/                 // UI pages grouped by feature
  services/
    local/                 // Hive + encrypted repositories
    remote/                // Marketplace API placeholder
  state/                   // Riverpod providers + AsyncNotifiers
  theme/app_theme.dart     // Material theme replacing FlutterFlowTheme
  widgets/                 // Reusable UI components
```

## Storage & security

- **Hive + AES encryption**: `EncryptedStorageService` bootstraps Hive, generates a per-installation key, stores it in `flutter_secure_storage`, and encrypts every box (cycles, marketplace prefs, user profile).
- **Repositories** convert between domain models and encrypted JSON blobs. All reads/writes are mediated through `CycleRepository`, `MarketplaceRepository`, and `UserRepository`.
- **Key management**: the raw AES key never leaves the device. Add biometrics or PIN-gated flows later by wrapping the key creation logic in `EncryptedStorageService`.

## State management

- **Riverpod** anchors all state. Providers live in `state/`:
  - `cycleEntriesProvider` (AsyncNotifier) exposes local cycle logs.
  - `marketplacePreferencesProvider` merges remote offers + stored scopes.
  - `userProfileProvider` loads encrypted profile data.
- Providers depend on repositories via constructor injection, which makes unit testing straightforward.

## Navigation & UI

- `AppRouter` defines routes for `Home`, `LogCycle`, `Marketplace`, `Profile`, `Terms`, and `FAQ`.
- Reusable widgets (`PrimaryButton`, `AppBottomNavigation`, `SymptomChip`, `EmptyState`) replace FlutterFlow widgets.
- `AppTheme` mirrors the original palette (pink primary, rounded buttons) without relying on `FlutterFlowTheme`.

## Marketplace architecture

1. **Local-first logging** – `LogCycleScreen` writes encrypted entries via `cycleEntriesProvider`.
2. **Marketplace API** – `MarketplaceApi` placeholder describes how to pull offers and push encrypted payload metadata later.
3. **Data flow when opting in** (future):
   - User toggles scopes per organization.
   - App derives an encrypted insight bundle from selected `CycleEntry` data.
   - Encrypted blob hash posted to Marketplace API.
   - Reward claims reflected in `UserProfile`.

## Next implementation milestones

1. **Onboarding flow** – capture user display name, optional PIN/biometric gate for key unlock.
2. **Symptom catalog editor** – allow custom tags stored in encrypted Hive box.
3. **Insights & predictions** – derive fertile window + next period predictions locally, store in encrypted cache.
4. **Marketplace networking** – implement HTTPS client, auth, and signed request validation for publishing encrypted data.
5. **Testing & CI** – add unit tests for repositories/notifiers and lint/format hooks.




