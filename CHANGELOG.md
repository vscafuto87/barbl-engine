# Changelog

Versioni della knowledge base (`kb/VERSION`, semver). Ogni modifica che cambia un piano generato alza la versione. Il tag di rilascio ha la forma `vX.Y.Z` e coincide con `kb/VERSION`. Si crea con il workflow «Crea tag» (Actions, Run workflow), che controlla `kb/VERSION` e questa pagina; il workflow «Tag di rilascio» lo ricontrolla a tag creato.

## 0.14.0 — 2026-11-05

- Più varietà dal catalogo: 10 esercizi nuovi (curl a martello, curl su panca inclinata, alzate laterali alla macchina, pec deck inverso, pec deck, calf seduto, leg curl da seduto, rematore alla macchina, lat machine presa neutra, hack squat) inseriti nei candidati intercambiabili dei template (`equivalent` 2 o 3, sempre dentro l'attrezzatura del profilo). Ricerca sugli split (meta-analisi di Schoenfeld 2016 e 2019, Ramos-Campo 2024; letti solo i riassunti): a volume e frequenza pari lo split cambia poco per l'ipertrofia, e a 3 giorni la struttura che dà 10 serie a muscolo con due stimoli è comunque il Full body; per questo non aggiungo template nuovi e la varietà viene dal catalogo e dal seme. Nessun numero nuovo.

## 0.13.0 — 2026-11-05

- Copertura di tutta la matrice di 324 profili (prima 216): una seduta che non sta nella durata del profilo si accorcia (`P-TIME-TRIM`: si tolgono prima gli isolamenti, poi i complementari, mai i principali) invece di rifiutare il profilo, e `ppl_ul_5d` vale anche per la forza (prescrizione strength, stessa decisione di C-STRENGTH-VOLUME). Conflitto aperto `C-TIME-VOLUME`: con poco tempo il volume di alcuni muscoli scende sotto la soglia. Nessun numero nuovo.

## 0.12.0 — 2026-11-05

- Tantissimi piani per lo stesso profilo: `variantSeed` facoltativo nel profilo 1.3 (app barbl#56) mescolato nella scelta; senza seme il piano resta deterministico. `equivalent: 2` anche sugli esercizi secondari dei template per massa ed entrambi (spinte, trazioni orizzontali, stacchi, affondi, hip thrust, spalle); per la forza principali e secondari restano fissi (principio di design `P-STRENGTH-SPECIFICITY`). La chiave di scelta non include più obiettivo ed enfasi. L'hash ha un finalizzatore (i bit bassi di FNV-1a erano quasi solo parità). Caso d'oro 02 senza il carico del rematore con manubrio. Nessun numero nuovo.

## 0.11.0 — 2026-11-05

- Piani vari: gli slot di isolamento (braccia, spalle laterali e posteriori, polpacci, petto) dichiarano `equivalent: 2` e il motore assegna uno dei due primi esercizi disponibili con un hash deterministico di profilo (senza carichi noti), seduta e posizione. Stesso profilo, stesso piano; profili diversi possono avere esercizi diversi. Principio `P-EXERCISE-VARIATION` (tier 3, provvisorio), conflitto differito `C-LOAD-RATIO-EXERCISES` (nessun rapporto di carico con fonte). Nessun numero nuovo.

## 0.10.0 — 2026-11-04

- Alternative per «Sostituisci»: ogni esercizio del piano porta `alternatives` (contratto: campo facoltativo, app barbl#51), cioè i suoi sostituti della KB nell'ordine dichiarato, solo se eseguibili con l'attrezzatura del profilo e non già nella stessa seduta. Il carico delle alternative è `manual` (nessun rapporto tra esercizi ha ancora una fonte). Nessun numero nuovo.

## 0.9.0 — 2026-11-04

- Sposta seduta: `parameters.move.minRestHours.fullBody` = 48 ore per le sedute Full body (contratto: campo facoltativo, app barbl#47); `shiftsWeek` resta falso. I piani Full body cambiano solo in questo parametro.

## 0.8.0 — 2026-11-04

- Conversione dei carichi noti: un `knownLoads` con `reps` si converte in carico di lavoro (Epley, poi carico alle ripetizioni e al RIR della prima settimana, arrotondato al passo inferiore) con `source: estimate`; senza `reps` il carico vale com'è. Parametri in `parameters/trialLoad` (`knownLoadConversion`: divisore di Epley e RIR assunto 0), principio di design `P-KNOWN-LOAD-RIR`. Il caso d'oro 01 cambia (80 × 8 → 77,5 kg).

## 0.7.0 — 2026-11-04

- Enfasi del profilo 1.2 (`emphasis`, al massimo due tra `glutes_hamstrings`, `shoulders`, `arms`): il motore aggiunge uno slot in coda a una o due sedute per template, solo se la seduta resta entro `sessionDurationMin`. Motivazione `EMPHASIS`, KB in `kb/emphasis/`, caso d'oro 05. Pull request #9.

## 0.6.0 — 2026-11-04

- Template `ppl_ul_5d` (5 giorni, massa ed entrambi), esercizi per spalle e glutei, copertura dei 45 minuti a 5 giorni, caso d'oro 04. Pull request #7.

## 0.5.0 — 2026-11-04

- Prescrizione `strength` e obiettivo forza nei template, caso d'oro 03, eval a matrice di 324 profili. Pull request #5 e #6.

## 0.4.0 — 2026-11-04

- Template `full_body_3d` (3 giorni), caso d'oro 02. È la versione usata dall'app fino a oggi (commit `01bd162`). Pull request #4.

## 0.3.0 — 2026-11-04

- Contratto 3.0: nomi `{ it, en }`, `askLoad`, `source: manual` per i carichi a mano. Pull request #3.

## 0.2.0 — 2026-11-01

- Primo motore: generazione dei piani dalla KB. Pull request #2.
