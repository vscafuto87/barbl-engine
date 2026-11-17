# Livello avanzato: piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Piani separati e più duri per chi ha `experience: over_2_years` (3, 4, 5 giorni), con cedimento sull'ultima serie, drop set, myo-reps e superset, e l'app che li mostra e li registra.

**Architecture:** La KB dichiara template, prescrizioni e parametri avanzati; il motore sceglie il template per esperienza e scrive nel piano 3.2 `lastSet` e `rirFloor` per esercizio e `parameters.intensityTechniques`. L'app legge questi campi, costruisce le righe (cedimento, drop, mini-serie myo) e applica le regole di progressione approvate il 15/11/2026.

**Tech Stack:** YAML + JSON Schema + Python (validatore) nella KB; Dart puro (`barbl_engine`, `packages/progression`); Flutter, Riverpod, Drift nell'app.

**Spec:** `barbl-engine/docs/superpowers/specs/2026-11-15-livello-avanzato-design.md` (leggerla prima di ogni task).

## Global Constraints

- Nessun numero di dominio nel codice Dart (motore e app): tutto dalla KB e da `parameters` del piano.
- Mai testo copiato dalle fonti; mai nomi commerciali. Fonti con `use: internal` solo come riferimento (titolo, pagina).
- Principi nuovi `status: provisional`, gruppi di parametri `provisional: true`.
- `generatePlan` resta puro e deterministico; varietà con `variantSeed` come oggi.
- Cedimento, drop set e myo-reps: mai su slot `main`, mai su esercizi segnati `heavyCompound`, mai nello scarico, mai prima di `intensityTechniques.fromWeek`.
- `drop_set` e `myo_reps` solo su ruolo `accessory` in blocchi `single`; dentro un superset solo `failure`.
- Con `goal: strength` l'unica tecnica è `failure` sugli isolamenti.
- Volume previsto: drop set = 0 serie in più; blocco myo-reps = 1 serie.
- Regola 1: una serie prescritta a cedimento ha RIR target 0 (registrato in `target_rir`); drop e mini-serie myo fuori dalla regola 1 e dai record.
- Recupero delle mini-serie myo-reps da orario di fine, solo nell'app (nessuna `RestTimerSurface`), anche con «Avvia il recupero» spento.
- Piano `schemaVersion` `3.2` solo se il piano contiene `lastSet` o `rirFloor`; l'app legge 3.0, 3.1, 3.2.
- App: nessun testo nei widget (ARB it/en), stili solo dai token, bersagli `barblTouchSize`, un solo primario.
- Unione delle PR (novembre 2026): `flutter analyze`, `flutter test --exclude-tags golden`, `cd packages/progression && dart test`; nel motore `dart test` e `python3 kb/tools/validate.py`; esito scritto nella PR. Nel cloud Dart e Flutter si scaricano nello scratchpad.
- Commit e testi in italiano; rami `claude/project-thread-q5xhtu`.

## Review Focus

1. Settimana di scarico con un esercizio che ha `lastSet`: nessuna riga di cedimento, drop o myo; RIR dello scarico.
2. Esercizio con `lastSet: drop_set` sostituito con «Sostituisci» da un'alternativa con bilanciere pesante: la tecnica resta solo se l'alternativa la ammette (`heavyCompound` falso), altrimenti l'ultima serie è normale.
3. Drop set con un carico che arrotondato per difetto vale 0 kg o meno del primo passo (manubri leggeri): nessuna riga drop, la serie a cedimento resta.
4. Seduta riaperta a metà di un blocco myo-reps (app chiusa): le mini-serie già registrate restano, la riga successiva riparte con il recupero da orario di fine già scaduto.
5. Utente che registra RIR 2 su una serie prescritta a cedimento: la regola 1 la valuta con target 0 (nessun blocco), la regola 2 non scatta.

---

## Parte 1 — Contratto 3.2 nell'app (`barbl`, PR 1)

### Task 1: Schema e modello del piano 3.2

**Files:**
- Modify: `docs/contratto/plan.schema.json`, `docs/contratto/README.md`
- Modify: `packages/progression/lib/src/plan/exercise.dart`, `plan.dart`, `packages/progression/lib/src/parameters/parameters.dart`
- Create: `packages/progression/lib/src/parameters/intensity_techniques_params.dart`
- Test: `packages/progression/test/plan/plan_test.dart`, `test/contract/plan_schema_test.dart` (o l'esistente `plan_schema_test`)

**Interfaces:**
- Produces: `enum LastSetTechnique { failure, dropSet, myoReps }` (JSON `failure`, `drop_set`, `myo_reps`); `Exercise.lastSet: LastSetTechnique?`; `Exercise.rirFloor: int?`; `Parameters.intensityTechniques: IntensityTechniquesParams?` con `fromWeek: int`, `dropLoadReductionPct: num`, `dropDrops: int`, `myoActivationReps: RepsRange`, `myoMiniSetReps: RepsRange`, `myoRestSeconds: int`, `myoMaxMiniSets: int`, `myoStopWhenRepsBelow: int`. `Plan.readableSchemaVersions = {'3.0','3.1','3.2'}`.

- [ ] **Step 1:** Test `plan 3.2 round-trips lastSet, rirFloor and intensityTechniques` (un esercizio `lastSet: myo_reps`, uno `rirFloor: 1`, blocco `intensityTechniques` completo; `toJson` riscrive gli stessi campi, solo se presenti); test `plan 3.1 without the new fields reads as before` (`lastSet` nullo, `intensityTechniques` nullo); test di schema: un 3.2 valido passa, `lastSet: "partial"` fallisce.
- [ ] **Step 2:** Esegui `cd packages/progression && dart test test/plan/` → FAIL.
- [ ] **Step 3:** Schema: in `exercise` aggiungi `lastSet` (enum) e `rirFloor` (integer ≥ 0), in `parameters` la proprietà facoltativa `intensityTechniques` con i campi sopra (`required` tutti dentro il gruppo); `schemaVersion` enum aggiunge `3.2`. README: sezione «3.2» con significato dei campi e delle regole della spec. Modello e `toJson` come `optional` (scritto solo se presente).
- [ ] **Step 4:** `dart test` e `flutter test test/contract` → PASS.
- [ ] **Step 5:** Commit «Contratto 3.2: lastSet, rirFloor e intensityTechniques».

### Task 2: Regole di progressione e domini delle tecniche

**Files:**
- Modify: `docs/logica-progressione.md` (regole 15–17, casi di test), `docs/decisioni.md`
- Modify: `packages/progression/lib/src/history/set_kind.dart`, `logged_set.dart`, `progression/double_progression.dart`, `lib/data/workout/mapping.dart` (`toLoggedSet` porta `targetRir`)
- Create: `packages/progression/lib/src/progression/intensity_techniques.dart`
- Test: `packages/progression/test/progression/intensity_techniques_test.dart`, `double_progression_test.dart`

**Interfaces:**
- Produces:
  - `SetKind.myo` (testo `myo` nel database, nessun cambio di schema); `countsAsWork` falso per `myo`.
  - `LoggedSet.targetRir: int?`.
  - `bool techniqueActive({required Plan plan, required Exercise exercise, required int weekNumber})` — vero se `exercise.lastSet != null`, `intensityTechniques != null`, la settimana è di carico e `weekNumber >= fromWeek`.
  - `int? exerciseRirTarget({required Plan plan, required Exercise exercise, required int weekNumber})` — `max(rirTargetForWeek, exercise.rirFloor ?? 0)`, null se l'esercizio non segue il mesociclo.
  - `num? dropLoadKg({required num kg, required num reductionPct, required LoadSteps steps})` — `steps.roundDown(kg * (1 - pct/100))`; null se ≤ 0 o uguale a `kg`.
  - `bool myoContinues({required List<int> miniSetReps, required IntensityTechniquesParams p})` — falso dopo `myoMaxMiniSets` mini-serie o se l'ultima ha meno di `myoStopWhenRepsBelow` ripetizioni.
- Consumes: Task 1.

- [ ] **Step 1:** Test di `nextTarget`: (a) ultima serie `failure` con `targetRir: 0`, reps al massimo, le altre a RIR ≥ target della settimana → `increase`; (b) serie `failure` senza `targetRir` (scelta dall'utente) → blocca come oggi (A6); (c) serie `failure` prescritta registrata a RIR 2 → non blocca; (d) serie `drop` e `myo` ignorate. Test delle quattro funzioni nuove con i valori di un `IntensityTechniquesParams` di prova (es. pct 25 su 40 kg con passo 2,5 → 30; scarico → `techniqueActive` falso; `rirFloor 1` in settimana a RIR 0 → 1).
- [ ] **Step 2:** `dart test` → FAIL.
- [ ] **Step 3:** In `nextTarget` `below(s)` usa `s.targetRir ?? last.targetRir`. Implementa le funzioni; esportale dal barrel.
- [ ] **Step 4:** `dart test` → PASS. Scrivi in `logica-progressione.md` le regole 15 (cedimento prescritto), 16 (drop set prescritto), 17 (myo-reps) con i casi di test, testo approvato da Vincenzo il 15/11 (vedi spec, «Decise da Vincenzo»); righe in `decisioni.md`.
- [ ] **Step 5:** Commit «Regole 15-17: cedimento, drop set e myo-reps prescritti».

Apri la PR 1 sull'app (analisi e test in locale, scritti nella PR); uniscila prima della Parte 2.

## Parte 2 — KB 0.31.0 e motore (`barbl-engine`, PR 2)

### Task 3: Schemi e modelli della KB

**Files:**
- Modify: `kb/schema/template.schema.json`, `prescription.schema.json`, `exercise.schema.json`, `parameter.schema.json`; `kb/contract/` (copia da PR 1 con `SOURCE.md`)
- Modify: `engine/lib/src/kb/models.dart`, `knowledge_base.dart`
- Test: `engine/test/kb/` (modelli), `kb/tools/validate.py`

**Interfaces:**
- Produces: `KbTemplate.experience: List<String>` (vuota = tutte); `KbSlot.lastSet: String?`; `KbPrescription.experience: List<String>`; `KbExercise.heavyCompound: bool`; `KbRole.lastSetMinutes` non serve: tempo delle tecniche in `timeBudget.techniqueMinutes: {drop_set, myo_reps}` (`KbPrescription.techniqueMinutes: Map<String,int>`, vuota se assente).
- Validatore (anche in `knowledge_base.dart`, errore di caricamento): `lastSet` vietato su `role: main`; `drop_set`/`myo_reps` solo su `accessory` e solo in blocchi `single`; al più `maxTechniquesPerSession` slot `drop_set`/`myo_reps` per seduta (valore nel gruppo `intensityTechniques`); `lastSet` vietato se il primo candidato disponibile per una palestra è `heavyCompound`.

- [ ] **Step 1:** Test che caricano KB minime con ciascuna violazione → errore con il percorso; KB valida → ok.
- [ ] **Step 2:** `cd engine && dart test test/kb` → FAIL.
- [ ] **Step 3:** Implementa campi e controlli; stessi controlli in `validate.py`.
- [ ] **Step 4:** `dart test` e `python3 kb/tools/validate.py` → PASS.
- [ ] **Step 5:** Commit.

### Task 4: Selezione per esperienza e scrittura nel piano

**Files:**
- Modify: `engine/lib/src/generate/select_template.dart`, `prescribe.dart`, `plan_parameters.dart`, `assemble_plan.dart`, `weekly_volume.dart`, `fit_to_duration.dart`, `extend_to_duration.dart`, `rationales.dart`
- Test: `engine/test/generate/*_test.dart` corrispondenti

**Interfaces:**
- `selectTemplate`: tra i template con giorni e obiettivo, preferisce quello con `experience` che contiene `profile.experience`; altrimenti quello con `experience` vuota.
- Selezione della prescrizione: stessa regola su `KbPrescription.experience`.
- `PrescribedExercise.lastSet: String?` (dallo slot; tolto se l'esercizio scelto è `heavyCompound`, o se `goal == strength` e la tecnica non è `failure`); `rirFloor` scritto se l'esercizio è `heavyCompound` e il piano ha `minRirHeavyCompound`.
- Durata: `estimatedMinutes` somma `techniqueMinutes[lastSet]` per gli esercizi con tecnica; `fit_to_duration` toglie come oggi (la tecnica segue lo slot).
- Volume previsto (`weekly_volume`): nessuna serie in più per `lastSet`.
- `parameters.intensityTechniques` dal gruppo KB, scritto solo se il piano ha un `lastSet`; `mesocycle.weeks` da `weeksByExperience[experience]` se presente.
- `schemaVersion` `3.2` se il piano ha `lastSet` o `rirFloor`, altrimenti come oggi.
- Motivazioni `ADV-*` nell'elenco «solo se citate» (`_onlyWhenCited`) e citate in `rules` degli esercizi con tecnica.

- [ ] **Step 1:** Test: profilo `over_2_years` con template avanzato in KB di prova → sceglie l'avanzato; `6_months_2_years` → il normale; avanzato senza template dichiarato → il normale. Piano con `lastSet` → `schemaVersion` 3.2 e `intensityTechniques`; senza → invariato byte per byte (test esistenti verdi). `heavyCompound` scelto dal seme → niente `lastSet`, `rirFloor` presente. Strength → solo `failure`.
- [ ] **Step 2:** `dart test` → FAIL.
- [ ] **Step 3:** Implementa.
- [ ] **Step 4:** `dart test` → PASS (tutta la suite: i piani esistenti non cambiano).
- [ ] **Step 5:** Commit.

### Task 5: Contenuti della KB avanzata

**Files:**
- Create: `kb/sources/sodal-2023-drop-sets.yaml` e la revisione sui metodi avanzati (verificare autori e DOI di PMC11022786 prima di scriverla); `kb/principles/intensity/p-adv-failure-last-set.yaml`, `p-adv-failure-periodized.yaml`, `p-drop-set.yaml`, `p-myo-reps.yaml`; `kb/principles/structure/p-superset-antagonist.yaml`, `p-adv-structure.yaml`; `kb/prescriptions/advanced_muscle_gain.yaml`, `advanced_strength.yaml`; `kb/parameters/intensityTechniques.yaml`; `kb/templates/advanced_full_body_3d.yaml`, `advanced_upper_lower_4d.yaml`, `advanced_ul_ppl_5d.yaml`; `kb/rationales/ADV-*.yaml` (it/en).
- Modify: `kb/parameters/mesocycle.yaml` (`weeksByExperience.over_2_years`: RIR 2, 1, 1, 0, scarico 4; `minRirHeavyCompound: 1`), `kb/exercises/**` (`heavyCompound: true` su squat, stacchi, panca, rematore e military con bilanciere e varianti pesanti), `kb/conflicts.yaml` (C-RIR-BY-ROLE riaperto e richiuso il 15/11; C-ADVANCED-FAILURE), `kb/VERSION` → `0.31.0`, `CHANGELOG.md`.

Contenuti fissati dalla spec: 2–3 serie per esercizio, più esercizi per seduta, superset agonista-antagonista tra isolamenti in ogni seduta da 60 minuti, finisher degli addominali invariato, `maxTechniquesPerSession` 2, `fromWeek` 3. Valori ancora proposti (pct drop 20–25, `myoRestSeconds` 15, attivazione, mini-serie, soglia di arresto, `techniqueMinutes`): fondarli su Helms livello 5, Sødal 2023 e la revisione, citando pagine; se nessuna fonte li fissa, principio `design` dichiarato. Strutture dalle fonti della spec (Schoenfeld pp. 140–141; programmi Nippard per intermedi e avanzati come struttura, mai tabelle). Controlla i testi con `--sources-md ../barbl-sources/md`.

- [ ] **Step 1:** Aggiungi in `kb/golden/` profili `over_2_years` per 3, 4, 5 giorni, tre palestre, 45/60/75/90 min, con le proprietà: nessuna tecnica su main o `heavyCompound`; nessuna tecnica nello scarico (proprietà sul piano: `fromWeek` ≤ settimane di carico); volume nella fascia come i piani normali; durata ≤ scelta; almeno un superset per seduta da 60 min; due semi diversi → piani diversi.
- [ ] **Step 2:** `python3 kb/tools/validate.py` → FAIL (template mancanti).
- [ ] **Step 3:** Scrivi i file.
- [ ] **Step 4:** `python3 kb/tools/validate.py`, `--sources-md ../barbl-sources/md`, `cd engine && dart test` (anche `profile_matrix_test`: i 324 profili coperti) → PASS.
- [ ] **Step 5:** Commit «KB 0.31.0: livello avanzato»; PR 2, unione con test locali scritti nella PR; tag v0.31.0 se il permesso lo consente.

## Parte 3 — App con il motore nuovo (`barbl`, PR 3)

### Task 6: Motore aggiornato e righe della Seduta

**Files:**
- Run: `dart run tool/update_engine.dart <sha del merge della PR 2>`
- Modify: `lib/data/workout/proposals.dart` (RIR con `exerciseRirTarget`), `lib/data/workout/session_preview.dart`, `lib/features/session/state/layout.dart` (`buildRows`, `plannedRowCount`), controller della Seduta (recupero), `lib/data/workout/mapping.dart`
- Test: `test/features/session/state/layout_test.dart`, `test/features/session/state/session_controller_*_test.dart`, `test/data/workout/proposals_test.dart`

**Interfaces:**
- Consumes: Task 1–2.
- `SetRowView.technique: LastSetTechnique?` sulla riga che porta la tecnica; righe pianificate con `techniqueActive`: ultima serie di lavoro → `kind: failure`, `targetRir: 0`; `drop_set` → dopo di essa una riga `drop` con `dropLoadKg` (nessuna riga se null); `myo_reps` → dopo la serie di attivazione una riga `myo` allo stesso carico finché `myoContinues` è vero (righe derivate dalle serie registrate, come la prova).
- Recupero: `drop` nessun recupero; `myo` recupero `myoRestSeconds` da orario di fine solo nello stato della Seduta, senza `RestTimerSync.show`, anche con la preferenza spenta; la serie che chiude il blocco avvia il recupero normale.
- `plannedWeekSets` invariato (righe di lavoro = serie previste).

- [ ] **Step 1:** Test di `buildRows`: settimana 2 → righe normali; settimana 4 con `failure` → ultima riga `failure` target 0; `drop_set` → riga drop a 30 kg da 40 (pct 25, passo 2,5); `myo_reps` dopo attivazione registrata 12 rip → riga myo; dopo 3 mini-serie (max 3) → nessuna; scarico → nessuna tecnica; `rirFloor 1` → target 1 sulle righe dello squat in settimana 4. Test del controller: conferma di una riga myo → `restEndsAt` = ora + 15 s e nessuna chiamata a `FakeRestTimerSurface.show`; riga drop → nessun recupero. Review Focus 2–5.
- [ ] **Step 2:** `flutter test <file>` → FAIL.
- [ ] **Step 3:** Implementa.
- [ ] **Step 4:** Test → PASS; `flutter analyze`.
- [ ] **Step 5:** Commit.

### Task 7: Interfaccia (skill Taste e Impeccable)

**Files:**
- Modify: `lib/design_system/components/set_row.dart` (etichetta della tecnica, lettera della riga myo), `lib/features/session/widgets/exercise_header.dart` (badge della tecnica come «Facoltativo»), `lib/features/plan/screens/session_preview_screen.dart`, `lib/features/today/widgets/today_changes.dart`, `lib/l10n/app_it.arb`, `app_en.arb`, `lib/features/session/widgets/session_format.dart` (lettere: myo «M» in it ed en), catalogo
- Test: `test/design_system/components/set_row_test.dart`, `test/features/session/widgets/exercise_header_test.dart`, `session_preview_screen_test.dart`

Testi ARB (it / en): `setTechniqueFailure` «Cedimento» / «To failure»; `setTechniqueDropSet` «Drop set» / «Drop set»; `setTechniqueMyoReps` «Myo-reps» / «Myo-reps»; `setTechniqueSemantic` per lo screen reader «Ultima serie: {technique}» / «Last set: {technique}». Il «Perché?» mostra le motivazioni `ADV-*` del piano già citate in `rules` (nessuna frase nell'app).

- [ ] **Step 1:** Test: la riga con `technique` mostra l'etichetta e la semantica; la riga myo ha la lettera «M»; la testata mostra il badge; inglese a 320 e testo ×1,3 senza overflow; bersagli ≥ `barblTouchSize`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementa con i token esistenti (colore del tipo di serie come `failure` oggi); nessun token scritto a mano, eventuali token nuovi in `docs/design-tokens.json` + `dart run tool/generate_tokens.dart`.
- [ ] **Step 4:** PASS; `flutter gen-l10n`, `flutter analyze`.
- [ ] **Step 5:** Commit.

### Task 8: Flusso completo e documentazione

**Files:**
- Create: `test/app/advanced_plan_flow_test.dart`
- Modify: `docs/architettura.md` (sezione «Livello avanzato»), `docs/specifiche-ux-ui.md`, `docs/superpowers/prove-su-dispositivo.md` (prove e golden da rigenerare), `docs/decisioni.md`

- [ ] **Step 1:** Test di flusso (router, database in memoria, orologio manuale, pacchetto vero): onboarding con «più di 2 anni», 4 giorni, 60 min → piano 3.2 salvato; Seduta in settimana 4: ultima serie a cedimento, drop set a carico ridotto, blocco myo-reps con recupero di 15 s senza superficie esterna; Fine; Progressi: volume con il blocco myo = 1 serie, nessun record dalle mini-serie; settimana 5 (scarico) senza tecniche; profilo `6_months_2_years` → piano invariato.
- [ ] **Step 2:** Esegui → FAIL o verde; correggi.
- [ ] **Step 3:** Suite completa: `flutter analyze`, `flutter test --exclude-tags golden`, `cd packages/progression && dart test` → PASS.
- [ ] **Step 4:** Documentazione; memoria del progetto aggiornata; prossimo sviluppo annotato: piano a 6 giorni.
- [ ] **Step 5:** Commit, PR 3 con l'esito dei test, unione.
