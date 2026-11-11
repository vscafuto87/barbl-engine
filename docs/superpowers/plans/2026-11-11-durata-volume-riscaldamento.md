# Durata, volume, riscaldamento ed esperienza — piano

**Obiettivo:** realizzare `docs/superpowers/specs/2026-11-11-durata-volume-riscaldamento-design.md` (D1 estensioni, D2 riscaldamento, D3 esperienza) nel motore e nella KB, KB `0.25.0`.
**Ramo:** `claude/supabase-pr-99-followup-10g0s2` (da `main` a `711c527`). Nessuna PR e nessun merge senza richiesta.
**Verifica locale** (la CI di novembre non parte): `cd engine && dart analyze && dart test && dart run bin/barbl_engine.dart eval --kb ../kb`, `python3 kb/tools/validate.py`. Dart SDK ≥ 3.13.5.

## Vincoli globali

- `CLAUDE.md` della radice: nessun numero di dominio nel codice Dart; ogni numero della KB cita un principio (se non c'è fonte: principio `design`, fonte `barbl-design`, provvisorio); testi nostri in italiano e inglese; identificativi in inglese; niente consigli medici.
- `generatePlan` resta pura e deterministica e non lancia per un profilo.
- **Profili senza estensioni applicabili** (template senza `extensions`) e intermedi o avanzati: piano identico a prima per il RIR. Il resto cambia solo dove le estensioni o il riscaldamento lo prevedono.
- Commit piccoli in italiano, uno per task.

## Task 1 — Metadati: meccanica dei pattern e domanda tecnica

- Bundle e `KnowledgeBase`: leggere `mechanics` da `kb/vocab/patterns.yaml` (`patternMechanics`).
- `kb/schema/exercise.schema.json`: campo facoltativo `technicalDemand` (enum `high`); `KbExercise.technicalDemandHigh`.
- Test: `knowledge_base_test`, `bundle_builder_test`.

## Task 2 — Riscaldamento sul primo multiarticolare del pattern (D2)

- Schema delle prescrizioni: `warmup` accetta `always`, `firstCompoundOfPattern`, `never`, più `true` e `false`. `KbRole.warmup` diventa un enum.
- `prescribe.dart`: con `firstCompoundOfPattern`, `warmup` vero solo se il pattern è `compound` e non compare prima nella seduta.
- KB: `secondary: firstCompoundOfPattern` in `muscle_gain.yaml` e `strength.yaml`; principio `P-WARMUP-SPECIFIC` con la fonte `ribeiro-2021-warmup-review` (nuova, `abstract_only`); `parameters/warmup.yaml` e il commento di `vocab/patterns.yaml` allineati.
- Test: `prescribe_test` (panca poi chest press: solo la prima; military press complementare: sì; isolamento: no; superset).

## Task 3 — Estensioni (D1)

- Schema dei template: `extensions` (lista di `{session, slot}`); validatore: seduta esistente, pattern del primo candidato, copertura per palestra, ruolo `accessory` o `secondary`.
- `KbTemplate.extensions`; passo `engine/lib/src/generate/extend_to_duration.dart` secondo le quattro condizioni di D1. Estrarre il conteggio del volume frazionario in una funzione condivisa (`weeklyVolume`), senza duplicare quello di `eval_runner.dart`. Estrarre la scelta del candidato con `equivalent` e `stableHash` da `choose_exercises.dart` in una funzione riusabile, con l'esclusione degli esercizi già presenti.
- `generate_plan.dart`: `fitToDuration` → `applyEmphasis` → `extendToDuration` → `prescribe`.
- Principio `P-TIME-EXTEND` (design).
- Test unitari: aggiunge in ordine; salta per durata, per pattern già presente, per tetto, per candidati finiti; template senza estensioni invariato; deterministico.

## Task 4 — Estensioni nei tre template e taratura

- Scrivere le estensioni proposte nella specifica nei tre template.
- Rigenerare la matrice (216 profili più gli `under_6_months`) e un report per template, palestra e durata: serie per muscolo, minuti per seduta, estensioni applicate e saltate con il motivo. Correggere ordine e slot finché i criteri 1–4 della specifica valgono. Riportare i numeri nella PR.

## Task 5 — Esperienza (D3)

- `parameters/mesocycle.yaml`: `minRirTargetByExperience`; schema e lettura; `assemble_plan.dart` (o dov'è il mesociclo) applica il minimo alle settimane `load`.
- `technicalDemand: high` sugli esercizi della lista confermata da Vincenzo; ordinamento dei candidati per `under_6_months` in un solo punto usato da scelta, enfasi ed estensioni.
- Principi `P-RIR-BEGINNER` e `P-BEGINNER-SIMPLER` (design), conflitto `C-RIR-BEGINNER` chiuso con la decisione dell'11 novembre, motivazioni del mesociclo invariate (usano già i valori della settimana).
- Test: mesociclo del principiante 3, 3, 2, 2, 4; intermedio invariato; front squat mai scelto per un principiante con la palestra completa; scelto se è l'unico disponibile.

## Task 6 — Eval, casi d'oro, documenti, versione

- `profile_matrix_test.dart`: proprietà della specifica (criteri 1–6).
- Casi d'oro 06 (4 giorni 75 minuti), 07 (3 giorni 90 minuti), 08 (principiante 4 giorni 60 minuti); aggiornare 01–05 solo se le estensioni cambiano gli esercizi attesi.
- `kb/VERSION` `0.25.0`, `CHANGELOG.md`, `kb/README.md`, `docs/eval-matrice.md`, test della versione del bundle.
- Push sul ramo; descrizione della verifica locale pronta per la PR.

## Dopo (app, fase B1)

Su richiesta, nel repository dell'app sullo stesso nome di ramo: aggiornare il motore con `tool/update_engine.dart`, i test che leggono il piano vero, `docs/decisioni.md` e `docs/architettura.md`; verifica con `flutter analyze`, `flutter test --exclude-tags golden` e `cd packages/progression && dart test`.

## Punti da confermare prima di partire

1. Lista degli esercizi `technicalDemand: high`: `front_squat`, `good_morning`, `sissy_squat`, `single_leg_dumbbell_romanian_deadlift`, `bulgarian_split_squat`, `dip`.
2. Nessuna motivazione `TIME-EXTEND` nel piano in questa fase.
3. La fase B2 (soglia dei manubri, indicazione per i carichi a mano) si specifica a parte.
