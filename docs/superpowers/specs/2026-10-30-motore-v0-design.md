# barbl-engine v0 — specifica

Data: 30 ottobre 2026. Stato: da approvare.

## Obiettivo

Un motore in Dart puro che, dato un profilo del contratto dell'app, produce un piano conforme a `plan.schema.json` usando solo la knowledge base (KB) come fonte di numeri, esercizi e testi. Primo traguardo: il template upper/lower da 4 giorni della KB v0.1, per le tre palestre del profilo, con il caso d'oro 01 verde.

**Criterio di successo**: un comando genera da un profilo un piano valido rispetto allo schema del contratto, spiegabile (motivazioni con fonti) e con tutti i numeri presi dalla KB; le eval dei casi d'oro sono verdi in CI.

## Decisioni prese nel brainstorming

| # | Decisione | Motivo |
| --- | --- | --- |
| D1 | La KB arriva al motore come **pacchetto JSON** (`kb-bundle.json`) costruito dai YAML | Nell'app il motore gira offline; un pacchetto unico si include tra gli asset e in futuro si può aggiornare senza una nuova versione dell'app |
| D2 | Motore e app si scambiano **JSON del contratto**; il motore ha modelli interni propri | Il contratto resta l'unico punto di contatto (`docs/motore-e-regole.md` dell'app); il motore non dipende dal codice dell'app |
| D3 | Un profilo non coperto dalla KB dà un esito **«non coperto» con il motivo**; il motore non adatta un template | Nessuna regola senza fonte; l'app resta sul piano fisso finché la KB non copre il caso |
| D4 | **Un solo repository**: `barbl-engine` contiene `kb/` (l'attuale `barbl-kb`, con la storia) ed `engine/` | Schema della KB, modelli del motore ed eval cambiano insieme in una PR; niente `kb.lock`. `barbl-kb` viene archiviato |
| D5 | Gli esercizi di cui l'onboarding chiede il carico sono marcati nel template (`askLoad` sullo slot) | Cambiano con la palestra; la KB decide, l'app non cambia |
| D6 | Un carico da inserire a mano si scrive `{ "kg": null, "source": "estimate" }`, come il leg curl del piano fisso | Resta valido con il contratto di oggi; il valore `manual` arriva con il collegamento all'app (vedi «Modifiche dovute») |

## Struttura del repository

```
barbl-engine/
├── CLAUDE.md                 ← regole di lavoro (unione di quelle di barbl-kb e del motore)
├── README.md
├── kb/                       ← ex barbl-kb, storia conservata
│   ├── VERSION  schema/  contract/  vocab/  sources/  principles/
│   ├── exercises/  templates/  prescriptions/  parameters/  rationales/
│   ├── conflicts.yaml  golden/
│   └── tools/validate.py  requirements.txt
├── engine/                   ← pacchetto Dart barbl_engine
│   ├── pubspec.yaml
│   ├── lib/barbl_engine.dart ← API pubblica
│   ├── lib/src/kb/           ← modelli della KB e lettura del pacchetto
│   ├── lib/src/generate/     ← i sei passi
│   ├── lib/src/contract/     ← lettura del profilo, scrittura del piano
│   ├── lib/src/bundle/       ← YAML → pacchetto (solo riga di comando)
│   ├── bin/barbl_engine.dart ← riga di comando
│   └── test/
├── docs/superpowers/{specs,plans}/
└── .github/workflows/        ← kb.yml (Python, percorsi kb/**) ed engine.yml (Dart, ogni PR)
```

`build/` (pacchetto generato) è in `.gitignore`. Lo spostamento usa `git subtree add --prefix=kb` (o un `merge` con `--allow-unrelated-histories` dopo aver spostato i file in `kb/` nel ramo di origine), così `git log kb/` mostra la storia di barbl-kb. Il validatore Python e la sua CI restano com'erano, con i percorsi aggiornati.

## Modifiche alla KB comprese in questa specifica

- **`askLoad: true`** (facoltativo, booleano) sugli slot del template; schema e validatore aggiornati. In `upper_lower_4d` lo hanno gli slot di panca, rematore, military press (Upper A) e squat (Lower A), cioè gli esercizi che l'onboarding chiede oggi.
- **`everyExercise: true`** (facoltativo) nelle motivazioni `PROG-DOUBLE`, `PROG-RIR-CORRECTION`, `RECORD-EPLEY`; schema aggiornato.
- **Polpacci sotto fascia** registrati in `conflicts.yaml` come lacuna aperta del template.
- `VERSION` sale a `0.2.0` (cambia un piano generato: le sorgenti dei carichi).

## Pacchetto della KB

`barbl_engine bundle --kb kb --out build/kb-bundle.json` legge i YAML e scrive un JSON con:

```json
{
  "bundleFormat": 1,
  "rulesVersion": "0.2.0",
  "kbCommit": "<sha o null>",
  "muscles": {…}, "setWeights": {…}, "patterns": {…},
  "equipment": { "profile": […], "gymTypes": {…}, "plan": […] },
  "sources": {…}, "principles": {…}, "exercises": {…},
  "templates": {…}, "prescriptions": {…},
  "parameters": {…}, "rationales": {…}
}
```

- Le mappe sono indicizzate per `id` (o `group` per i parametri, `ruleId` per le motivazioni) e scritte con le chiavi in ordine: lo stesso input dà gli stessi byte.
- Non entrano nel pacchetto `conflicts.yaml`, `golden/` e le note (servono alla validazione, non alla generazione).
- `bundle` rifiuta una KB con un riferimento mancante (esercizio, principio, fonte, gruppo di parametri, pattern, muscolo, attrezzatura) e stampa l'elenco degli errori. Il validatore Python resta il controllo completo (schema, conferme, copie dai libri); `bundle` controlla solo ciò che serve al motore per non fallire.
- `kbCommit` arriva da `--kb-commit` (la CI passa `GITHUB_SHA`); senza, è `null`.
- La lettura YAML (`package:yaml`) sta solo in `lib/src/bundle/` e in `bin/`; la libreria che va nell'app non la importa.

## API della libreria

```dart
/// La KB letta dal pacchetto JSON.
class KnowledgeBase {
  factory KnowledgeBase.fromJson(Map<String, Object?> json); // lancia KbFormatException se il formato non è valido
  String get rulesVersion;
}

sealed class GenerationResult {}
final class Generated extends GenerationResult { final Map<String, Object?> plan; }
final class NotCovered extends GenerationResult { final NotCoveredReason reason; final String detail; }
final class InvalidProfile extends GenerationResult { final List<String> errors; }

enum NotCoveredReason { days, goal, equipment, duration }

GenerationResult generatePlan(Map<String, Object?> profile, KnowledgeBase kb);
```

- `generatePlan` è sincrona, pura e deterministica: nessun orologio, nessuna casualità, nessun I/O. Non lancia per un profilo: un profilo malformato dà `InvalidProfile`, uno ben formato che la KB non copre dà `NotCovered`.
- `detail` è un testo tecnico in inglese per il log e le eval (es. `no template for daysPerWeek=3 goal=muscle_gain`), non un testo per l'utente.
- Il piano è una `Map` pronta per `jsonEncode`, con le chiavi nell'ordine del piano fisso.

## Generazione: i sei passi

Ogni passo è una funzione pura in `lib/src/generate/`, con test propri.

### 1. Lettura del profilo e scelta del template

- Il profilo si legge con le regole di `profile.schema.json` 1.0: campi obbligatori, valori enumerati, default in lettura (`barKg` 20, `platesKg` della lista standard). Errori → `InvalidProfile`.
- Template: il primo (in ordine di `id`) con `daysPerWeek` uguale e `goal` contenuto in `goals`. Nessun template con quei giorni → `NotCovered(days)`; giorni coperti ma non l'obiettivo → `NotCovered(goal)`.
- Calendario: `defaultSchedule` del template, nell'ordine dei giorni della settimana.

### 2. Scelta degli esercizi

- In ogni slot, il primo candidato il cui `requires` è contenuto in `gym.equipment` del profilo. Nessun candidato → `NotCovered(equipment)` con slot e seduta nel `detail`.
- `gym.equipment` del profilo è letto come lista di stringhe (oggi l'app non usa un enum); valori sconosciuti sono ignorati.

### 3. Prescrizione e durata

- Prescrizione: quella con `goal` del profilo in `appliesTo`. Per ogni esercizio, dal ruolo dello slot: `sets`, `reps` (o `repsOverride` dello slot), `rirFollowsMesocycle`, `warmup`, `restSeconds` dal `focus` della seduta (`upper` per `upper_body`, `lower` per `legs`; `full_body` non ha ancora una colonna nelle prescrizioni, quindi `bundle` rifiuta un template che lo usa).
- Superset: `restSeconds` del blocco = `supersetRestSeconds`; negli esercizi del superset `restSeconds` è `null`; `label` dal template.
- `stepKg` dall'esercizio; `equipment`, `muscles` (primario, poi secondari) e `name` (italiano, come il piano fisso) dall'esercizio.
- Durata: `estimatedDurationMin` = somma delle serie della seduta × `timeBudget.minutesPerSet`. Se una seduta supera `sessionDurationMin` → `NotCovered(duration)`; il motore non toglie serie.

### 4. Carichi iniziali

Per ogni esercizio scelto:

- **Carico noto**: voce di `knownLoads` con lo stesso `exerciseId` e `kg` numerico → `{kg, source: "profile"}`, qualunque sia lo slot. Le `reps` della voce non si usano (TODO nel codice: la conversione non è ancora una regola della KB).
- **Prova possibile**: slot con `askLoad`, nessun `kg` noto (voce con `kg: null` oppure nessuna voce, perché l'onboarding non ha ancora chiesto), esercizio con `loading.whenLoadUnknown: trial_set` e `reps.min` + RIR target più alto del mesociclo ≤ `trialLoad.engineConstraints.maxRepsPlusRir` → `{kg: null, source: "trial_set"}`.
- **Tutti gli altri** → `{kg: null, source: "estimate"}` (D6: l'utente scrive il carico alla prima serie).

Effetto voluto sull'app: generando il piano con `knownLoads` vuoto, gli esercizi con sorgente `trial_set` sono quelli da chiedere nell'onboarding (`keyExerciseIds` dell'app li trova già). Un esercizio `askLoad` che non può avere la prova (es. manubri nella palestra «solo manubri») avrebbe sorgente `estimate` e l'onboarding non lo chiederebbe: è un limite noto, registrato tra le modifiche dovute.

### 5. Mesociclo, parametri e motivazioni

- `mesocycle.weeks` dal gruppo `mesocycle` della KB.
- `parameters`: un oggetto per ogni gruppo della KB con `target: parameters`, con `ruleId`, `provisional` e i `values` appiattiti come nel contratto.
- `rules` di ogni esercizio: le motivazioni della KB marcate con il nuovo campo `everyExercise: true` (nella KB v0.2: `PROG-DOUBLE`, `PROG-RIR-CORRECTION`, `RECORD-EPLEY`, come nel piano fisso), più `TRIAL-LOAD` sugli esercizi con sorgente `trial_set`. L'app oggi non legge `rules` per decidere nulla (la regola 8 e «Stanco» arrivano dalle proposte), quindi `VOL-BAND` non va sugli esercizi.
- `rationales`: tutte le motivazioni della KB (ogni regola dei `parameters` ha la sua frase nel «Perché?»), con `level`, `key`, `text` it/en dalla KB; `values` = `exampleValues` della KB, come fa il piano fisso: molti segnaposto li riempie l'app in seduta (`{kg}`, `{setNumber}`, `{muscle}`, `{week}`…) e i `values` del piano servono da esempio. Il validatore della KB controlla già che i segnaposto siano uguali in italiano e in inglese. `sources`: dai principi (diretti o del gruppo `sourcesFrom`) alle fonti, senza doppioni, in ordine di `tier` e poi di `id`, con `title` e `reference` della fonte («—» se manca), `url` ed `evidence` (`high` per tier 1-2, `medium` per 3-4, `low` per 5). Le fonti con `use: internal` (libri e programmi acquistati) e quelle di tipo `design` non compaiono nell'app: il «Perché?» cita solo fonti pubbliche. Una motivazione che resta senza fonti pubbliche esce con `sources` vuoto.
- `generatedBy`: `{ "engine": "barbl-engine <versione del pacchetto Dart>", "rulesVersion": <VERSION della KB> }`. `id` del piano: l'id del template seguito dal tipo di palestra (`upper_lower_4d-full`).

### 6. Controlli finali

Prima di restituire `Generated`, il motore ricontrolla il piano e, se un controllo fallisce, lancia un `StateError` (è un errore della KB o del motore, non del profilo):

- ogni seduta entro `sessionDurationMin` (già garantito dal passo 3);
- ogni `ruleId` citato da un esercizio ha la sua motivazione;
- ogni esercizio del piano esiste nella KB e la sua attrezzatura è nel profilo.

Il volume settimanale per muscolo non è un controllo della libreria: dipende dal profilo e lo verificano i casi d'oro in `eval` (`weeklySetsAtLeast`). Un controllo generale (ogni muscolo allenato ≥ `bandMin`) fallirebbe oggi sui polpacci, che il template allena con un solo esercizio: è una lacuna della KB da registrare in `conflicts.yaml`, non da nascondere.

La validazione contro `plan.schema.json` non è nella libreria (nessuna dipendenza nell'app): sta nei test e in `eval`.

## Riga di comando

```
dart run barbl_engine bundle   --kb ../kb --out ../build/kb-bundle.json [--kb-commit SHA]
dart run barbl_engine generate --profile p.json [--bundle ../build/kb-bundle.json | --kb ../kb]
dart run barbl_engine eval     [--kb ../kb]
```

- `generate` scrive il piano su stdout (JSON indentato) ed esce con 0; con «non coperto» o profilo non valido scrive l'esito su stderr ed esce con 2.
- `eval` costruisce il pacchetto in memoria, genera un piano per ogni file di `kb/golden/`, verifica le proprietà `expect` (le stesse chiavi del validatore Python: `split`, `sessions`, `scheduleDays`, `mesocycle`, `initialLoad`, `weeklySetsAtLeast`, `validAgainst`) e lo schema del contratto (`json_schema`), stampa una riga per caso ed esce con 1 se uno fallisce.

## Test

- **Unità**, per ogni passo, su KB minime costruite nel test (nessun file della KB vera).
- **Pacchetto**: `bundle` sulla KB vera dà un JSON che `KnowledgeBase.fromJson` legge; due esecuzioni danno gli stessi byte; un riferimento rotto dà errore con il nome del file.
- **Flusso sulla KB vera**:
  - caso d'oro 01 verde;
  - le tre palestre (`full`, `home`, `dumbbells`) danno piani validi rispetto allo schema e diversi tra loro;
  - 3 e 5 giorni → `NotCovered(days)`; obiettivo `strength` → `NotCovered(goal)`; 45 minuti → `NotCovered(duration)`;
  - un profilo senza `gym` → `InvalidProfile`;
  - `knownLoads` vuoto → sorgenti `trial_set` esattamente sugli slot `askLoad` che possono avere la prova;
  - stesso profilo e stessa KB → stesso JSON byte per byte.
- **Architettura**: nessun file di `lib/` fuori da `lib/src/bundle/` importa `package:yaml`, `dart:io` o `package:json_schema`.

## CI e verifica

- `kb.yml`: il workflow di barbl-kb, su `kb/**`.
- `engine.yml`: su ogni PR e su `main`, `dart-lang/setup-dart` (stable), `dart pub get`, `dart analyze --fatal-infos`, `dart format --set-exit-if-changed`, `dart test`, `dart run barbl_engine eval`.
- Nell'ambiente di lavoro di Claude l'SDK di Dart non si scarica: la verifica è la CI della PR (e Vincenzo può lanciare gli stessi comandi sul Mac). Nessun lavoro si dichiara finito senza la CI verde.

## Modifiche dovute quando il motore si collega all'app (fuori da questa specifica)

1. `initialLoad.source: "manual"` nel contratto (D6), con `schemaVersion` 2.1; il motore passa da `estimate` a `manual`.
2. Esercizi `askLoad` senza prova (manubri, macchine): l'onboarding deve chiederli anche se la sorgente non è `trial_set`. Serve un segno esplicito nel piano (es. `askLoad: true` sull'esercizio) invece della deduzione dalla sorgente.
3. Nome dell'esercizio in italiano e inglese: oggi `name` è una stringa sola; la KB ha già i due nomi.
4. `gym.equipment` del profilo come enum (decisione del 30 ottobre).
5. Conteggio frazionario nella regola 8 (`C-RULE8-FRACTIONAL`).
6. `RulesPlanGenerator` nell'app, con il pacchetto tra gli asset e la gestione di `NotCovered`.

## Fuori dall'ambito

Servizio HTTP; template a 3 e 5 giorni; obiettivo forza; conversione dei carichi noti (`reps` di `knownLoads`); adattamento del piano tra un mesociclo e l'altro; motivazioni generate da un modello linguistico.

## Rischi

- **CI come unico banco di prova**: ogni errore di compilazione costa un giro sulla PR. Mitigazione: task piccoli, un commit per task, CI veloce.
- **Campi nuovi nella KB** (`askLoad`, `everyExercise`): sono scelte di formato, non regole di dominio; se l'implementazione ne richiede altri ci si ferma e si chiede.
