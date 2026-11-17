# BingeLog integrations

## TMDB — primary metadata provider

Use TMDB for movie and TV search, details, credits, images, genres, videos, recommendations, trending content, seasons, and episodes.

Implementation notes:
- Start with read-only API access.
- Use Swedish language and Sweden region where supported, with sensible fallback to original titles and English metadata.
- Build image URLs from TMDB's configuration/image rules rather than hardcoding image sizes.
- Cache metadata and images according to provider guidance.
- Keep TMDB IDs on the BingeLog media record for stable cross-provider matching.
- Include TMDB attribution in the app's About/Credits area and the required non-endorsement notice.
- Confirm the correct TMDB license before any commercial distribution.

## Jellyfin — optional personal media server

Connection is user-configured and opt-in.

Initial scope:
- Server URL and authentication flow.
- Retrieve the signed-in user's libraries and media.
- Match local items to BingeLog records using provider IDs when available, then safe title/year matching as a fallback.
- Read playback progress and watched state.
- Add optional live progress/scrobble support only after the basic sync is reliable.
- Clearly show last successful sync and connection status.

Sync rules:
- Never silently overwrite a manual BingeLog rating.
- Allow the user to choose whether Jellyfin watched state updates BingeLog.
- Prevent loops if BingeLog later sends watched state back to Jellyfin.
- Store Jellyfin access tokens in Keychain.

## MDBList — personal list import and ratings enrichment

BingeLog includes an optional read-only import of the authenticated user’s MDBList lists. The user enters an MDBList API key in the Importera tab; store it in iOS Keychain and never commit it.

Import behavior:
- Fetch the authenticated user’s lists from `/lists/user/` and list items from `/lists/{listid}/items/`.
- Page in batches of 100 and respect MDBList’s 1,000-item maximum per list.
- Match using TMDB ID plus media type; skip entries without a TMDB ID rather than guessing from title alone.
- Add new entries as “Vill se”; never overwrite an existing BingeLog status, personal rating, or diary data.
- Keep import one-way and local. Disconnecting MDBList must not remove imported entries.

Use MDBList as an optional enrichment provider for:
- Aggregated ratings and vote counts from supported sources.
- Public and curated lists.
- Catalog/discovery queries where useful.
- Cross-reference IDs and TVDB episode mapping where needed.

Implementation notes:
- Keep MDBList ratings visually distinct from the user's own BingeLog rating.
- Respect account tier quotas and rate limits; cache responses and back off on HTTP 429.
- API keys must not be committed to the repository.
- Treat MDBList/Jellyfin plugin synchronization as an optional user setup, not a hard dependency of BingeLog.

## Integration order

1. TMDB search/details and media identity.
2. BingeLog-owned watchlist, status, ratings, and diary.
3. MDBList ratings and curated-list enrichment.
4. Jellyfin connection and read-only library/progress import.
5. Optional two-way sync and live scrobbling after conflict handling is tested.

## References

- TMDB API: https://developer.themoviedb.org/docs
- TMDB FAQ and attribution: https://developer.themoviedb.org/docs/faq
- Jellyfin API: https://api.jellyfin.org/
- MDBList API: https://api.mdblist.com/docs/
- MDBList integrations: https://mdblist.com/apps/
