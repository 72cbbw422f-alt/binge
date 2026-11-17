# BingeLog architecture

## Product rule

BingeLog owns the user's personal data. External services enrich the experience; they do not become the source of truth for the user's diary.

## Initial app structure

- `App/` — app entry point and navigation shell
- `Design/` — shared colors, spacing, typography, and components
- `Features/` — feature-specific screens and view models
- `Domain/` — app-owned models and business rules
- `Data/` — repositories, persistence, and service adapters
- `Integrations/` — TMDB, Jellyfin, and MDBList clients

## Core domain entities

- MediaItem: canonical BingeLog identity plus external IDs (TMDB, IMDb, TVDB, Jellyfin)
- MovieDetails
- ShowDetails
- Season
- Episode
- WatchEntry: watched timestamp, source, progress, and optional playback session ID
- UserRating: BingeLog's own rating, separate from imported external ratings
- WatchlistEntry
- CustomList
- ProviderAvailability
- NotificationPreference

## Data ownership and conflict rules

1. BingeLog's own watch diary and ratings are authoritative for manually entered activity.
2. Jellyfin playback events may update progress and watched state when the user explicitly enables sync.
3. MDBList ratings are external reference values and never overwrite a BingeLog rating.
4. TMDB supplies descriptive metadata and artwork, not personal tracking state.
5. Every imported or synced change should retain its source and sync timestamp.
6. Disconnecting a provider must not delete the user's BingeLog history.

## Security

- Store user credentials and tokens in iOS Keychain.
- Never commit API keys, passwords, server URLs containing credentials, or personal tokens.
- Use HTTPS for remote integrations.
- Make provider connections opt-in and explain what data is synchronized.
- Avoid logging authorization headers or personal watch history.

## Build strategy

Native SwiftUI, iOS-first, with an XcodeGen project definition. Keep service clients independent of views so integrations can be tested and replaced without rewriting the UI.
