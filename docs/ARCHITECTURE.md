# BingeLog architecture

## Product rule

BingeLog owns the user's personal data. External services enrich the experience; they do not become the source of truth for the user's diary. The app is local-first: the current library, ratings, episode progress, and activity history are stored on-device with SwiftData.

## Current application structure

- `Sources/BingeLog/App/` — app entry point, tab shell, and home dashboard
- `Sources/BingeLog/Design/` — shared colors, spacing, typography, and visual components
- `Sources/BingeLog/Models/` — SwiftData models for saved media, episode progress, and activity events
- `Sources/BingeLog/Features/` — Discover, Collection, Detail, Import, and profile screens
- `Sources/BingeLog/Integrations/TMDB/` — TMDB API models and metadata service
- `Sources/BingeLog/Integrations/MDBList/` — optional MDBList list import
- `Sources/BingeLog/Integrations/Security/` — Keychain-backed token storage

## Implemented local entities

- `BingeEntry` — a saved movie or series, its TMDB metadata, personal rating, status, and key status dates
- `BingeEpisodeProgress` — watched timestamp for a series episode, identified by TMDB series ID, season, and episode
- `BingeWatchEvent` — chronological local activity for status changes and episode watch/unwatch actions

The home screen derives its watching/planned counts, continue-watching shelf, and recent activity from these local records. Series detail derives overall and per-season watched counts from `BingeEpisodeProgress` and the season episode totals supplied by TMDB.

## Integrations and data ownership

- TMDB supplies descriptive metadata, artwork, credits, trailers, and season/episode catalog data. It does not own personal tracking state.
- MDBList is an optional source for importing the user's own lists. Import adds missing records as planned; it must not overwrite existing statuses, personal ratings, or watch history.
- Jellyfin is a possible future integration and is not currently implemented.

## Data ownership and conflict rules

1. BingeLog's own watch diary, episode progress, and ratings are authoritative for manually entered activity.
2. External ratings never overwrite a BingeLog personal rating.
3. TMDB supplies descriptive metadata and artwork, not personal tracking state.
4. Imports must preserve existing local records and user edits.
5. Disconnecting a provider must not delete the user's BingeLog history.

## Security

- Store user credentials and API tokens in iOS Keychain.
- Never commit API keys, passwords, server URLs containing credentials, or personal tokens.
- Use HTTPS for remote integrations.
- Make provider connections opt-in and explain what data is imported or synchronized.
- Avoid logging authorization headers or personal watch history.

## Build strategy

Native SwiftUI, iOS 17+, SwiftData persistence, and an XcodeGen project definition. GitHub Actions builds the app for the iOS Simulator with code signing disabled. A successful simulator build does not produce a distributable IPA. Keep service clients independent of views where practical so integrations can be tested and replaced without rewriting the UI.

## Planned, not yet implemented

- Calendar for premieres and upcoming episodes
- Jellyfin connection and optional playback synchronization
- Cloud synchronization and multi-device sharing
- Notifications and release reminders
