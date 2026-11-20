# SwiftData – migrationspolicy

Det här dokumentet beskriver hur BingeLog ska utveckla sin lokala SwiftData-modell utan att förlora användarens bibliotek, betyg eller tittarhistorik.

## Nuläge

De nuvarande persistenta modellerna finns i `Sources/BingeLog/Models/`:

- `BingeEntry`: bibliotekspost, TMDB-identitet, metadata, personligt betyg, status och statusdatum.
- `BingeEpisodeProgress`: avsnittsframsteg identifierat logiskt av serie-TMDB-ID, säsong och avsnittsnummer.
- `BingeWatchEvent`: historiska status- och avsnittshändelser.

Appen använder SwiftData. Projektets nuvarande `project.yml` deklarerar iOS 17 som lägsta version. I den granskade koden finns ingen explicit `VersionedSchema` eller `SchemaMigrationPlan`. Det betyder inte att databasen saknar schemahantering; SwiftData hanterar den aktuella modellen, men framtida inkompatibla modelländringar måste planeras uttryckligt.

## Datainvarianter

Följande regler är bindande:

1. En biblioteksposts logiska identitet är kombinationen `mediaKind + tmdbID`. Film och serie med samma numeriska TMDB-ID är olika poster.
2. Ett avsnittsframsteg identifieras logiskt av `seriesTMDBID + seasonNumber + episodeNumber`.
3. Ett personligt betyg (`userRating`) ägs av användaren och får aldrig ersättas av TMDB-, MDBList- eller Jellyfin-data.
4. Status, start-/slutdatum och aktivitetshistorik är lokal användardata.
5. Importflöden ska lägga till saknade poster, inte uppdatera befintliga poster med extern status eller betyg.
6. Borttagning av en bibliotekspost får enligt nuvarande livscykelpolicy inte automatiskt radera avsnittsframsteg eller aktivitetshistorik.
7. En leverantörs frånkoppling får inte radera lokala poster eller historik.

## När en schemaändring planeras

Innan en persistent modell ändras:

1. Identifiera exakt vilka fält och typer som ändras.
2. Avgör om ändringen är additiv, omdöpning, typändring, borttagning eller ändring av relation/identitet.
3. Dokumentera hur befintliga poster översätts till den nya modellen.
4. Bevara befintliga värden för personliga betyg, statusar, datum, avsnittsframsteg och historik.
5. Skriv migreringstester med både representativa äldre data och tom databas.
6. Verifiera uppgradering från den senast distribuerade appversionen, inte bara från en nyinstallation.
7. Lägg inte till unikhetskrav eller relationer innan befintliga dubbletter och föräldralösa poster har inventerats och en säker åtgärd har testats.

Destruktiva modelländringar får inte lösas genom att radera den lokala databasen eller återskapa användarens bibliotek från externa tjänster.

## Migreringsstrategi

- Använd SwiftDatas versionshanterade schema och migrationsplan när en modelländring kräver kontrollerad versionsövergång.
- Håll varje migration så liten och avgränsad som möjligt.
- En migration ska vara deterministisk och får inte bero på nätverk, TMDB, MDBList eller Jellyfin.
- Externa ID:n får inte användas för att gissa eller slå ihop poster när identiteten är tvetydig.
- Om en säker automatisk migrering inte är möjlig ska appen bevara originaldata och rapportera ett hanterbart fel i stället för att kasta bort data.
- Engångsmigreringar i UserDefaults/Keychain ska ha versionsnyckel, idempotent beteende och tester för tomt, delvis migrerat och redan migrerat tillstånd.

## Obligatoriska tester

Varje ändring av persistenta modeller ska minst täcka:

- Ny installation med tom SwiftData-container.
- Läsning av data skapad med föregående schema.
- Bevarande av personligt betyg och status.
- Bevarande av start-/slutdatum.
- Bevarande av avsnittsframsteg och historik.
- Film/serie med samma TMDB-ID utan identitetskollision.
- Dubbletter i importerade poster utan att befintliga användarvärden ändras.
- Upprepad migrering utan dubbla poster eller ytterligare dataförändring.
- Avbruten eller misslyckad persistens utan partiell import.

## Test- och releasekrav

- Kör XcodeGen-generering, simulatorbyggning och hela XCTest-sviten i GitHub Actions.
- Testa uppgradering med en kopia av en representativ äldre lokal databas när schema ändras.
- Testa omstart efter migrering och kontrollera att data finns kvar.
- Redovisa separat vad som verifierats på simulator respektive fysisk enhet.
- En grön simulatorbyggning är inte bevis på att en IPA är signerad eller att migreringen fungerat på en fysisk installation.

## Relaterad dokumentation

- [Arkitektur](ARCHITECTURE.md)
- [Datans livscykel](DATA_LIFECYCLE.md)
- [Integrationer](INTEGRATIONS.md)
