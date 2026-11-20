# BingeLog architecture

## Product rule
BingeLog owns the user's personal data. External services enrich the experience; they do not become the source of truth for the user's diary. The app is local-first: the current library, ratings, episode progress, and activity history are stored on-device with SwiftData.

## Current application structure
- `Sources/BingeLog/App/` — app entry point, tab shell, and home dashboard
- `Sources/BingeLog/Design/` — shared colors, spacing, typography, and visual components
- `Sources/BingeLog/Models/` — SwiftData models for saved media, episode progress, and activity events
- `Sources/BingeLog/Features/` — Discover, Collection, Detail, Calendar, Import, and profile screens
- `Sources/BingeLog/Integrations/TMDB/` — TMDB API models and metadata service
- `Sources/BingeLog/Integrations/MDBList/` — optional MDBList list import
- `Sources/BingeLog/Integrations/Jellyfin/` — Jellyfin server authentication and session service
- `Sources/BingeLog/Integrations/Security/` — Keychain-backed token storage

## Implemented local entities
- `BingeEntry` — a saved movie or series, its TMDB metadata, personal rating, status, and key status dates
- `BingeEpisodeProgress` — watched timestamp for a series episode, identified by TMDB series ID, season, and episode
- `BingeWatchEvent` — chronological local activity for status changes and episode watch/unwatch actions

The home screen derives watching/planned/completed counts, personal rating insights, monthly activity totals, active days, a continue-watching shelf, and recent activity from these local records. The full activity screen groups events by calendar day. Series detail derives overall and per-season watched counts from `BingeEpisodeProgress` and the season episode totals supplied by TMDB.

## Integrations and data ownership
- TMDB supplies descriptive metadata, artwork, credits, trailers, and season/episode catalog data. It does not own personal tracking state.
- MDBList is an optional source for importing the user's own lists. Import adds missing records as planned; it must not overwrite existing statuses, personal ratings, or watch history.
- Jellyfin is an opt-in integration. The app authenticates through Jellyfin's MediaBrowser API and stores the server address, account name, user ID, and access token in iOS Keychain; the password is never persisted. The library screen retrieves movies and series in paginated requests, includes Jellyfin user-data markers for titles marked as played, matches items by their TMDB provider ID or an explicit user-selected TMDB match scoped to the connected server, and lets the user import new matches as planned. Items without a TMDB ID are shown separately and can be searched against TMDB by title; the user must select a type-compatible result before it is added. Bulk import rolls back inserted records if persistence fails. Imports do not overwrite local ratings, statuses, or watch history. For matched titles, the app compares Jellyfin's explicit played state with BingeLog's completed status. A Jellyfin-to-BingeLog status change is available only for titles Jellyfin marks as played, requires per-title user confirmation, records a local activity event, and preserves the personal rating. No status is written back to Jellyfin. Disconnect ends the server session on a best-effort basis and removes locally stored connection credentials.
- The release calendar combines upcoming movie releases with relevant upcoming TV episodes for titles in the user's local collection. It caches results, supports manual refresh, and surfaces partial provider failures.

## Data ownership and conflict rules
1. BingeLog's own watch diary, episode progress, and ratings are authoritative for manually entered activity.
2. External ratings never overwrite a BingeLog personal rating.
3. TMDB supplies descriptive metadata and artwork, not personal tracking state.
4. Imports must preserve existing local records and user edits.
5. Disconnecting a provider must not delete the user's BingeLog history.
6. Future Jellyfin synchronization must be explicit and must not silently replace personal ratings or local watch history.

## Security
- Store user credentials and API tokens in iOS Keychain.
- Never commit API keys, passwords, server URLs containing credentials, or personal tokens.
- Use HTTPS for remote integrations where available; local/private Jellyfin servers may require HTTP on a trusted network.
- Make provider connections opt-in and explain what data is imported or synchronized.
- Avoid logging authorization headers or personal watch history.
- The Jellyfin password is used only for the authentication request and is not saved.

## Build strategy
Native SwiftUI, iOS 17+, SwiftData persistence, and an XcodeGen project definition. GitHub Actions builds the app for the iOS Simulator with code signing disabled. A successful simulator build does not produce a distributable IPA. Keep service clients independent of views where practical so integrations can be tested and replaced without rewriting the UI.

## Planned, not yet implemented
- Optional Jellyfin playback/watch-state synchronization with clear conflict rules
- Cloud synchronization and multi-device sharing
- Notifications and release reminders

## SwiftData transaction boundaries
- Multi-record user actions must be committed as one logical transaction. For example, changing a title's status and inserting its activity event, or changing episode progress and inserting its watch event, must succeed or fail together.
- Feature-level mutations in the detail and collection screens use a dedicated `ModelContext` created from the app's `ModelContainer`. Autosave is disabled for that transaction context; the operation explicitly saves once all related mutations are ready.
- A failed transaction rolls back only its own context. Feature code must not call `rollback()` on the shared environment `ModelContext`, because that can discard unrelated pending edits.
- Deleting a `BingeEntry` removes only the library membership record. `BingeEpisodeProgress` and `BingeWatchEvent` are retained so a title can be re-added without losing the user's history.
- SwiftData `@Query` remains the read path for views; mutations are fetched by stable media identity inside the transaction context.
