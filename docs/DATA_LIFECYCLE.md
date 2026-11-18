# Datans livscykel

BingeLog skiljer på biblioteksposter, avsnittsframsteg och aktivitetshistorik. De tre datatyperna har olika syften och ska inte raderas automatiskt tillsammans.

## När en titel tas bort ur samlingen

- Själva `BingeEntry`-posten tas bort. Filmen eller serien försvinner därmed från biblioteket och dess status och personliga betyg finns inte längre kvar som aktiv bibliotekspost.
- `BingeEpisodeProgress` behålls. Avsnitt som markerats som sedda ligger kvar kopplade till seriens TMDB-ID.
- `BingeWatchEvent` behålls. Tidigare statusändringar och avsnittshändelser finns kvar i aktivitetshistoriken.

## Om titeln läggs till igen

En serie med samma TMDB-ID kan återanvända sina sparade avsnittsframsteg. Aktivitetshistoriken finns också kvar som historik. Den nya biblioteksposten börjar däremot med standardstatusen som anges av den aktuella import- eller tilläggsvägen; tidigare personligt betyg och bibliotekets datumfält återställs inte automatiskt.

## Varför detta är avsiktligt

Att ta bort en titel ur samlingen ska inte i tysthet radera vad användaren tidigare har tittat på. En framtida separat funktion för att radera all data om en titel måste därför vara uttrycklig och tydligt beskriva att även avsnittsframsteg och aktivitetshistorik tas bort.

## Identifiering

Biblioteksposter identifieras logiskt med kombinationen medietyp och TMDB-ID. Avsnittsframsteg identifieras med serie-TMDB-ID, säsongsnummer och avsnittsnummer. Aktivitetshändelser sparar TMDB-ID, medietyp, titeltext och tidpunkt så att historiken kan visas även om biblioteksposten inte längre finns.
