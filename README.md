# BingeLog

**En personlig film- och serietracker för iOS.** BingeLog byggs som en native SwiftUI-app med lokal SwiftData-lagring och ett mörkt grafittema med limegröna accenter.

## Funktioner

- Personligt bibliotek för filmer och serier med status, betyg och sökning.
- Detaljsidor med metadata, bilder, medverkande och trailers från TMDB.
- Säsongs- och avsnittshantering med tittarframsteg.
- Startsida med statistik och aktivitetshistorik.
- Kalender för kommande film- och seriepremiärer.
- Valfri import av personliga MDBList-listor.
- Valfri Jellyfin-anslutning för bibliotek, manuell TMDB-matchning och jämförelse av tittarstatus.

## Dataprinciper

- Personliga betyg, statusar och historik lagras i BingeLog och är appens källa till sanning.
- Import ska inte skriva över befintliga poster, betyg eller tittarhistorik.
- Överföring av sedd-status från Jellyfin till BingeLog kräver användarens bekräftelse.
- BingeLog skickar inte tillbaka ändringar till Jellyfin.
- API-nycklar och åtkomsttoken ska aldrig checkas in i Git.

## Teknik

- SwiftUI, Swift 5.9 och iOS 17 eller senare.
- SwiftData för lokal datalagring.
- Keychain för API-nycklar och integrationstoken.
- XcodeGen för att generera Xcode-projektet.
- GitHub Actions för kontinuerlig simulatorbyggning.

## Bygg lokalt

Kräver macOS med Xcode och XcodeGen:

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project BingeLog.xcodeproj -scheme BingeLog -destination 'generic/platform=iOS Simulator' build
```

## CI och teststatus

GitHub Actions bygger för **iOS Simulator** med kodsignering avstängd. En grön CI-byggning verifierar att projektet kompilerar för simulatorn, men är inte en signerad IPA och bevisar inte att funktionerna har testats på fysisk iPhone.

Aktuell utveckling och byggresultat finns under [GitHub Actions](https://github.com/72cbbw422f-alt/binge/actions). Före första live-test ska appen även byggas för fysisk enhet, signeras och installeras på iPhone. Därefter ska integrationer, importflöden, omstart och offline-beteende testas praktiskt.

## Dokumentation

- [Arkitektur](docs/ARCHITECTURE.md)
- [Integrationer](docs/INTEGRATIONS.md)
- [Datans livscykel](docs/DATA_LIFECYCLE.md)
- [TMDB-konfiguration](docs/TMDB_SETUP.md)

## TMDB-attribution

Denna produkt använder TMDB API men är inte godkänd eller certifierad av TMDB. TMDB-data och bilder omfattas av TMDB:s villkor och attributionskrav. Kommersiell användning kräver lämplig licens.
