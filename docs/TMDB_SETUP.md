# TMDB setup

1. Create or sign in to a TMDB account.
2. Open https://www.themoviedb.org/settings/api and request API access.
3. Copy the **API Read Access Token** (Bearer token), not the short v3 API key.
4. In BingeLog, open Upptäck → settings → paste the token.
5. The token is stored in iOS Keychain and is not committed to the repository.

BingeLog currently uses TMDB's `/search/multi` endpoint with `language=sv-SE`. Movie and TV results are displayed; person results are excluded from the first discovery list.

Official documentation:
- https://developer.themoviedb.org/docs/getting-started
- https://developer.themoviedb.org/docs/authentication-application
- https://developer.themoviedb.org/docs/search-and-query-for-details

TMDB requires its attribution and non-endorsement notice in the application. Confirm the applicable license before commercial distribution.
