# BingeLog

**Your personal movie & TV tracker.**

BingeLog is an iOS-first film and television companion inspired by the clarity and usefulness of modern tracking apps, with its own polished native SwiftUI experience.

## Product direction

- Track movies, shows, seasons, and individual episodes.
- Keep personal watch status, ratings, lists, and history in BingeLog.
- Discover titles and retrieve metadata from TMDB.
- Optionally connect a Jellyfin server for library and playback progress.
- Use MDBList as an enrichment source for ratings, curated lists, and discovery.
- Treat Swedish streaming availability and release dates as first-class product features.

## Integrations

| Service | Responsibility |
| --- | --- |
| TMDB | Primary movie/TV metadata, artwork, people, trailers, and discovery |
| Jellyfin | Optional user-owned media server, library and playback state |
| MDBList | Optional ratings aggregation, lists, and discovery enrichment |

Personal tracking data belongs to BingeLog and must remain usable if any external integration is disconnected.

## Project status

The repository is being initialized. Current work is the native SwiftUI app shell, design tokens, and integration boundaries. No API credentials or server tokens belong in source control.

## Build

The Xcode project is generated from `project.yml` using XcodeGen:

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project BingeLog.xcodeproj -scheme BingeLog -destination 'generic/platform=iOS Simulator' build
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/INTEGRATIONS.md](docs/INTEGRATIONS.md).

## Attribution

TMDB data and images require the attribution and notice specified by TMDB. BingeLog is not endorsed or certified by TMDB. Commercial use requires the appropriate TMDB license.
