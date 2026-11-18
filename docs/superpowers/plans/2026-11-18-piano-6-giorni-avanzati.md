# Piano a 6 giorni per avanzati — piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** chi ha `experience: over_2_years` può scegliere 6 sedute a settimana e riceve dal motore un piano avanzato Push/Pull/Gambe × 2.

**Architecture:** profilo `1.6` (`daysPerWeek` 6) nel contratto dell'app; template `advanced_ppl_6d` nella KB 0.33.0, scelto dal motore solo per `over_2_years` (gli altri: `NotCovered`); nell'app il passo dell'esperienza precede quello dei giorni e la scheda «6» dipende dall'esperienza.

**Tech Stack:** Dart puro (`barbl_engine`, `packages/progression`), Flutter 3.50 + Riverpod, YAML + JSON Schema + validatore Python.

**Spec:** `barbl-engine/docs/superpowers/specs/2026-11-18-piano-6-giorni-avanzati-design.md`

## Global Constraints

- Nessun numero di dominio nel codice (motore e app): valori solo nella KB e nei `parameters` del piano. Le liste di scelta dell'onboarding stanno in `packages/progression/lib/src/profile/profile_choices.dart`.
- Nessun testo dell'interfaccia nei widget: ARB `lib/l10n/app_it.arb` (sorgente) e `app_en.arb`.
- Profilo: si scrive `1.6` solo con `daysPerWeek == 6`; si leggono anche `1.0`–`1.5`. Il piano resta `3.3`.
- KB: mai testo delle fonti; ogni numero cita principi; nuovi principi `provisional`; `kb/VERSION` = `0.33.0` con voce in `CHANGELOG.md`.
- Nomi Dart, campi e id in inglese; commit in italiano con le righe di attribuzione della sessione.
- Ramo `claude/project-thread-y4w62t` in entrambi i repository; PR con verifica locale nella descrizione (CI senza minuti a novembre).
- Verifica app: `flutter analyze`, `flutter test --exclude-tags golden`, `cd packages/progression && dart test`. Verifica motore: `cd engine && dart test`, `python3 kb/tools/validate.py`.

## Review Focus

1. «Cambia piano» con un profilo salvato a 6 giorni: si cambia l'esperienza in «Da 6 mesi a 2 anni» → numero e giorni della settimana azzerati, «Continua» spento al passo dei giorni (test in Task 3).
2. Indietro dal passo dei giorni all'esperienza e ritorno: con «Più di 2 anni» la scelta a 6 resta (test in Task 3).
3. Sei giorni scelti con `weekdays` personalizzati (es. martedì–domenica): nessun avviso di recupero per il PPL × 2 (test in Task 4, `scheduleRecoveryClashes`).
4. Un profilo `1.6` riletto dal database e riscritto resta `1.6`; un profilo a 6 giorni con esperienza non avanzata (arrivato dal server) si legge senza errori e ricade sul piano fisso (test in Task 1 e Task 4).
5. Settimana di 6 sedute nel Piano, in Oggi e nei promemoria: sei righe, nessun overflow a 320 punti in inglese con testo ×1,3 (test in Task 4).

---

### Task 1: Contratto del profilo 1.6 (repository `barbl`, PR 1)

**Files:**
- Modify: `docs/contratto/profile.schema.json` (`daysPerWeek` enum `[3, 4, 5, 6]`, `weekdays.maxItems` 6, descrizioni)
- Modify: `docs/contratto/README.md` (voce «`daysPerWeek` 6, profilo `1.6`, solo per `over_2_years` lato app; il motore la copre dalla KB 0.33.0»; riga del versionamento)
- Modify: `packages/progression/lib/src/profile/profile_choices.dart`
- Modify: `packages/progression/lib/src/profile/profile.dart`
- Test: `packages/progression/test/profile/profile_choices_test.dart`, `packages/progression/test/profile/profile_test.dart`, `test/data/plan/plan_schema_test.dart` o il test che valida i profili contro lo schema (cercare `profile.schema.json` in `test/`)

**Interfaces:**
- Produces: `const List<int> daysPerWeekChoices = [3, 4, 5, 6];` `List<int> daysPerWeekChoicesFor(Experience? experience)` (6 solo con `Experience.over2Years` o il nome reale dell'enum; con `null` → `[3, 4, 5]`); `Profile.sixDaysSchemaVersion = '1.6'`; `Profile.readableSchemaVersions` contiene `'1.6'`.

- [ ] **Step 1: test che falliscono**
  - `profile_choices_test`: `daysPerWeekChoices` uguale all'enum dello schema (il test esistente lo fa già: deve diventare rosso dopo la modifica dello schema); `daysPerWeekChoicesFor(over2Years) == [3,4,5,6]`, per ogni altra esperienza e per `null` `== [3,4,5]`.
  - `profile_test`: un profilo `1.6` con `daysPerWeek: 6` e sei `weekdays` si legge e `toJson()['schemaVersion'] == '1.6'` (anche con `emphasis`, seme, manubri); un profilo con `daysPerWeek: 6` e cinque `weekdays` è rifiutato; un profilo `1.5` con 5 giorni si riscrive `1.5` come oggi; un profilo a 6 giorni con `experience: '6_months_2_years'` si legge senza errori.
- [ ] **Step 2: eseguire** `cd packages/progression && dart test test/profile` → FAIL.
- [ ] **Step 3: implementare** schema, scelte e `Profile` (versione scritta: `1.6` se 6 giorni, prima di ogni altra regola; la lettura accetta 6 da `1.6`, e la validazione dei `weekdays` usa `daysPerWeek`).
- [ ] **Step 4: eseguire** `dart test` nel pacchetto e `flutter test test/data` (o i test che leggono lo schema) → PASS. `flutter analyze` pulito.
- [ ] **Step 5: commit, push, PR 1** «Contratto: profilo 1.6 con 6 giorni»; unire con verifica locale scritta nella PR (regola di novembre). Annotare lo SHA di merge per il Task 2.

### Task 2: KB 0.33.0 e motore (repository `barbl-engine`, PR 2)

**Files:**
- Modify: `kb/contract/profile.schema.json` (copia dallo SHA di merge del Task 1), `kb/contract/SOURCE.md`
- Modify: `engine/lib/src/contract/profile.dart` (`_daysPerWeekValues` con 6, versione `1.6` tra le leggibili; le costanti di formato sono ammesse)
- Create: `kb/templates/advanced_ppl_6d.yaml`
- Create (se serve): `kb/principles/…/p-six-days-advanced.yaml` (tipo `design`, `provisional`), riferimenti alle fonti interne `The Ultimate Push Pull Legs System 6X` e `Powerbuilding 2.0 5-6xweek` (aggiungere le fonti in `kb/sources/` se mancano: solo titolo, autore, pagina, `use: internal`)
- Create: `kb/golden/NN-advanced-6d-*.yaml` (almeno: 60 min muscle_gain commercial; 45 min both; 90 min strength; 75 min palestra con soli manubri; un intermedio a 6 giorni atteso `NotCovered`)
- Modify: `kb/VERSION` (`0.33.0`), `CHANGELOG.md`
- Test: `engine/test/contract/profile_test.dart`, `engine/test/generate/*` (il test che genera ogni template avanzato), test della matrice dei profili se enumera `daysPerWeek`

**Interfaces:**
- Consumes: schema del Task 1.
- Produces: un piano `3.3` con `template` / id `advanced_ppl_6d…`, 6 sedute `push_a, pull_a, legs_a, push_b, pull_b, legs_b`, calendario lun–sab; `generatePlan` → `NotCovered` per `daysPerWeek: 6` con esperienza ≠ `over_2_years`.

- [ ] **Step 1: test che falliscono** nel motore: lettura di un profilo `1.6` a 6 giorni; generazione per `over_2_years` a 6 giorni (6 sedute, ogni seduta con almeno un `lastSet` da 60 minuti in su, nessun `lastSet` su `main` o esercizi `noFailure`, nessuna tecnica in scarico, durata rispettata, volume settimanale per muscolo nella fascia, finisher addome in due sedute non consecutive, nessun muscolo primario in due giorni consecutivi del calendario, piani diversi con due semi); `NotCovered` per `6_months_2_years` e `under_6_months` a 6 giorni. Riusare gli helper dei test dei template avanzati esistenti; se la matrice dei profili enumera i giorni, aggiungere 6 solo con `over_2_years`.
- [ ] **Step 2: eseguire** `cd engine && dart test` → FAIL.
- [ ] **Step 3: scrivere il template** sul modello di `advanced_ul_ppl_5d.yaml`: giro A con `main` pesante (panca/rematore/squat), giro B con `main` diversi (inclinata o manubri, trazioni/lat machine, pressa o hack/front squat); `hinge` solo nelle sedute delle gambe; tecniche negli slot secondo le regole del validatore; meno slot per seduta del 5 giorni finché il volume resta nella fascia; `goals: [muscle_gain, both, strength]`, `experience: [over_2_years]`, `sources` con i due programmi a 6 giorni.
- [ ] **Step 4: aggiornare lettore del profilo, contratto e golden**; `python3 kb/tools/validate.py` e `python3 kb/tools/validate.py --sources-md ../barbl-sources/md` senza errori; `cd engine && dart test` → PASS. Se un passo del motore assume ≤ 5 sedute, correggerlo e dirlo nella PR.
- [ ] **Step 5: VERSION 0.33.0, CHANGELOG** (template, volume per muscolo misurato, fonti, scelte `design`); commit, push, PR 2, unire con verifica locale; annotare lo SHA di merge.

### Task 3: Onboarding e «Cambia piano» (repository `barbl`, PR 3)

**Files:**
- Modify: `lib/features/onboarding/state/onboarding_draft.dart` (ordine dell'enum `OnboardingStep`: goal, gym, experience, schedule, emphasis, loads, notifications, finish; `copyWith` con un modo di azzerare `daysPerWeek`, es. `clearDays: true`)
- Modify: `lib/features/onboarding/state/onboarding_state.dart` (`setExperience`: se `draft.daysPerWeek` non è in `daysPerWeekChoicesFor(experience)` azzera numero e `weekdays`)
- Modify: `lib/features/onboarding/widgets/steps/schedule_step.dart` (schede da `daysPerWeekChoicesFor(draft.experience)`)
- Modify: test e golden dell'onboarding che contano passi o li attraversano in ordine (cercare `OnboardingStep.` e i flussi in `test/app/*flow_test.dart` che completano l'onboarding; aggiornare l'helper comune in `test/support/` se c'è)
- Modify: `docs/decisioni.md` (righe del 18/11: ordine dei passi, 6 giorni solo per avanzati), `docs/specifiche-ux-ui.md` (passo dei giorni)
- Test: `test/features/onboarding/state/onboarding_state_test.dart`, `test/features/onboarding/widgets/schedule_step_test.dart` (o il file esistente del passo 3), `test/features/onboarding/state/change_plan_state_test.dart`

**Interfaces:**
- Consumes: `daysPerWeekChoicesFor` (Task 1).
- Produces: `OnboardingStep` nel nuovo ordine; `OnboardingState.setExperience` che azzera i giorni non ammessi.

- [ ] **Step 1: test che falliscono**
  - stato: `steps` di `firstRun` e `changePlan` nel nuovo ordine; con `over_2_years` e `setDays(6)` + sei giorni `canContinue` vero; poi `setExperience(6_months_2_years)` → `daysPerWeek == null`, `weekdays` vuoti; con 4 giorni il cambio di esperienza non tocca nulla.
  - widget: con «Più di 2 anni» il passo mostra le schede 3, 4, 5, 6; con un'altra esperienza solo 3, 4, 5; a 320 punti, inglese, testo ×1,3 nessun overflow.
  - «Cambia piano»: `startChange` con un profilo salvato a 6 giorni riparte con 6 e i sei giorni; cambiando esperienza il passo dei giorni ha «Continua» spento.
  - Review Focus 2: indietro e avanti con «Più di 2 anni» conserva la scelta.
- [ ] **Step 2: eseguire** i test sopra → FAIL.
- [ ] **Step 3: implementare**; aggiornare gli altri test che attraversano l'onboarding (ordine dei passi) e i contatori «passo N di M» se cambiano.
- [ ] **Step 4: eseguire** `flutter test test/features/onboarding test/app` → PASS; `flutter analyze` pulito.
- [ ] **Step 5: commit** «Onboarding: esperienza prima dei giorni, 6 giorni per avanzati».

### Task 4: Motore aggiornato e settimana di 6 sedute (repository `barbl`, PR 3)

**Files:**
- Run: `dart run tool/update_engine.dart <SHA di merge del Task 2>` (riscrive `assets/engine/kb-bundle.json`, `assets/engine/ENGINE_REF`, `ref` in `pubspec.yaml`), poi `flutter pub get`
- Create: `test/app/six_day_plan_flow_test.dart` (router, database in memoria, orologio manuale, pacchetto vero; modello: `test/app/advanced_plan_flow_test.dart` e `five_day_plan_calendar_test.dart`)
- Modify: `docs/architettura.md` (nuova sezione «Piano a 6 giorni per avanzati (18 novembre 2026)» e riga del commit del motore), `docs/contratto/README.md` se serve
- Test: eventuali test esistenti che confrontano il pacchetto o il ref

**Interfaces:**
- Consumes: Task 2 (pacchetto KB 0.33.0), Task 3 (onboarding).

- [ ] **Step 1: aggiornare il motore** con lo script; `flutter test test/data/plan` → PASS (il test di pacchetto e ref).
- [ ] **Step 2: scrivere il flusso** `six_day_plan_flow_test.dart`: onboarding «Più di 2 anni» → 6 giorni lun–sab → piano salvato di origine `engine`, 6 sedute, `schemaVersion` del profilo `1.6`; Oggi di lunedì mostra Push; Piano mostra 6 righe nella settimana; settimana 4 con tecniche nella Seduta di una seduta; `scheduleRecoveryClashes` vuoto per lun–sab e mar–dom (Review Focus 3); profilo a 6 giorni con `6_months_2_years` scritto direttamente nel database → piano fisso (`origin: fixed`) senza errori (Review Focus 4); onboarding con «Da 6 mesi a 2 anni» senza la scheda «6». Promemoria: `upcomingTrainingDays` con il piano a 6 giorni dà 6 giorni nella settimana (Review Focus 5); Piano a 320 in inglese ×1,3 senza overflow.
- [ ] **Step 3: eseguire** il flusso; correggere ciò che assume ≤ 5 sedute.
- [ ] **Step 4: verifica completa**: `flutter analyze`, `flutter test --exclude-tags golden`, `cd packages/progression && dart test` → tutto verde.
- [ ] **Step 5: documenti, commit, push, PR 3** con la verifica locale e la nota «golden dell'onboarding da rigenerare su macOS»; unire con le regole di novembre.
