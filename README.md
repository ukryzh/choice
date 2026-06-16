# choice

**A privacy-first menstrual cycle tracker for Android.**

Your cycle data lives on your device, encrypted before it ever leaves it. No ads. No analytics. No data resale.

[Live page](https://ukryzh.github.io/choice/) · [Documentation](./docs) · [Contact](mailto:choice.period@gmail.com)

---

## Why choice exists

Most cycle-tracking apps monetize the most intimate kind of personal data - selling, sharing, or analyzing it. Privacy is usually declared, not enforced.

choice is a small, opinionated alternative built on a single rule: **the developer must not be able to read your cycle data, ever**.

It is treated as a product experiment. Nothing tracks you on the website, in the app, or anywhere in the pipeline.

## Features (MVP)

- Log periods with start and end dates
- View history in a calendar
- Predictions for the next cycle
- Symptom log per day
- Local-first storage on the device
- **Optional** end-to-end encrypted cloud backup
- Data recovery on a new device - only you can decrypt
- Full data deletion (local and cloud)
- Works without registration

## How privacy is enforced

- **Client-side encryption.** Each record is encrypted on the device with AES-256 before it is uploaded.
- **Per-record keys.** A leak of one key exposes one record, not the database.
- **Blind backend.** The server stores ciphertext only. It has no way to decrypt user data.
- **Keys never leave the device.** The encryption key is derived and stored locally.
- **Privacy by Design and by Default.** No analytics SDKs. No advertising SDKs. No third-party trackers.

See [docs/srs.html](./docs/srs.html) for the security model and [docs/regulatory.html](./docs/regulatory.html) for compliance details.

## Tech stack

| Layer | Choice |
|------|--------|
| Framework | Flutter |
| Language | Dart |
| Platforms | Android (initial release), iOS (roadmap) |
| Local storage | Hive / Isar |
| Encryption | AES-256 per-record · key in platform Keystore / Keychain |
| Cloud backup (optional) | Firebase (encrypted blobs only) |
| Auth (optional) | Google Sign-In, used for backup identity only |

## Documentation

The full product paper trail lives under [`/docs`](./docs):

- [Market research](./docs/marketing.html) - why this gap exists
- [Scope &amp; Vision](./docs/scope.html) - what is and isn't in MVP
- [Business Requirements (BRD)](./docs/brd.html)
- [Product Requirements (PRD)](./docs/prd.html) - user journeys
- [Software Requirements (SRS)](./docs/srs.html) - architecture and security
- [Regulatory compliance](./docs/regulatory.html) - GDPR, HIPAA, Google Play
- [Entity-relationship diagram](./docs/erd.html) - data model

## Status

**MVP - pre-release.** APK for Android. The Flutter client is open-sourced.

## Roadmap

- [x] Market research and scope
- [x] Privacy-first architecture
- [x] Cycle and symptom tracking
- [x] Local storage with predictions
- [x] Encrypted cloud backup
- [x] Cross-device recovery
- [x] APK release
- [x] Open-sourcing the Flutter client


## Local development of the landing

```bash
git clone https://github.com/ukryzh/choice.git
cd choice
# any static server, e.g.
python3 -m http.server 8000
# open http://localhost:8000
```

The page uses `fetch()` to load docs, so opening `index.html` directly via `file://` will not work - use a local server.

## Contact

choice is a solo project.

- **Email:** [choice.period@gmail.com](mailto:choice.period@gmail.com)
- **Repository:** [github.com/ukryzh/choice](https://github.com/ukryzh/choice)

## License

All rights reserved.
