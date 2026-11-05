# Changelog

Versioni della knowledge base (`kb/VERSION`, semver). Ogni modifica che cambia un piano generato alza la versione. Il tag di rilascio ha la forma `vX.Y.Z` e coincide con `kb/VERSION`. Si crea con il workflow «Crea tag» (Actions, Run workflow), che controlla `kb/VERSION` e questa pagina; il workflow «Tag di rilascio» lo ricontrolla a tag creato.

## 0.18.0 — 2026-11-05

- Tre enfasi nuove nel profilo (`emphasis`): `quadriceps`, `chest`, `back`, accanto a `glutes_hamstrings`, `shoulders` e `arms`; sempre al massimo due, stesse regole di durata. Posti: quadricipiti con la leg extension (Full A e Full C, Lower B, Gambe e Lower; senza macchine un affondo o uno squat con manubrio), petto con le croci (Full A e Full C, Upper A, Push e Upper), schiena con una trazione verticale o un rematore (Full A e Full C, Upper A e Upper B, Pull e Upper).
- L'enfasi non ripete più un esercizio già presente nella seduta: prende il primo candidato disponibile che la seduta non ha, e se non ce n'è nessuno salta il posto. Corregge il limite noto della 0.7.0 (con i soli manubri l'esercizio aggiunto ripeteva quello della seduta); a 4 e 5 giorni con i soli manubri l'enfasi schiena non trova esercizi nuovi e non aggiunge nulla. Ai curl dell'enfasi braccia si aggiungono il curl a martello e quello su panca inclinata come riserve.
- Principio `P-SEX-RESPONSE` (Roberts 2020, Refalo 2025, solo abstract; Schoenfeld p. 173): a parità di programma la crescita relativa è simile tra i sessi, quindi stesse regole per tutti e nessuna domanda sul sesso; le differenze di obiettivo passano dall'enfasi. Conflitto aperto `C-SEX-FATIGUE` (Nuckols 2026: le donne recuperano di più tra le serie, non tra le sedute), da rivedere con il coach.
- Matrice dell'enfasi da 432 a 756 profili (sette varianti). Nessun numero nuovo.

## 0.17.0 — 2026-11-05

- Terza tornata (manubri e casa), con letture degli studi: 3 esercizi nuovi (curl alla panca Scott con manubrio, stacco rumeno a una gamba con manubrio, Arnold press). Estesi `P-MUSCLE-LENGTH` (Maeo 2021: leg curl da seduto più dei ischiocrurali che da prono; Pedrosa 2023: curl nel tratto allungato) e nuovo `P-PUSH-UP-LOW-LOAD` (Kikuchi 2017). Di conseguenza il leg curl da seduto precede quello da prono (che passa in coda, dopo lo stacco rumeno a una gamba) e i curl allungati (panca inclinata, Scott) entrano per primi nei candidati dei bicipiti (`equivalent` 4); l'Arnold press è intercambiabile con la panca da seduto nelle spalle. Lo stacco rumeno a una gamba e l'Arnold press non hanno uno studio diretto: valgono per la varietà (`P-EXERCISE-VARIATION`). Principi provvisori, nessun numero nuovo, nessuno split nuovo.

## 0.16.0 — 2026-11-05

- Chiusi i cinque conflitti aperti (decisioni di Vincenzo): C-RIR-BY-ROLE, C-REST-STRENGTH, C-STRENGTH-VOLUME e C-TIME-VOLUME senza cambi al motore (scelte di design accettate); C-CALVES-BAND con un secondo esercizio per i polpacci in Lower B del template a 4 giorni (6 serie a settimana, come a 5 giorni) e l'eccezione dichiarata sotto le 10 serie. I piani a 4 giorni cambiano (uno slot in più, tolto per primo nelle sedute corte). Nessun numero nuovo.

## 0.15.0 — 2026-11-05

- Seconda tornata di catalogo, con letture degli studi: 8 esercizi nuovi (calf raise alla leg press e al multipower, estensioni sopra la testa con bilanciere, ponte per i glutei, pull-through ai cavi, affondi indietro, step-up, alzate posteriori su panca inclinata). Principio `P-MUSCLE-LENGTH` (Maeo 2023: tricipiti più cresciuti con le estensioni sopra la testa che con i pushdown; Kinoshita 2023, testo completo: gastrocnemi più cresciuti con il calf raise in piedi che da seduto; revisione di Pedrosa 2026): i candidati che allungano il muscolo vanno per primi e il pushdown e il calf seduto restano in coda, fuori dal gruppo intercambiabile. **Correzione della 0.14.0**, che aveva messo il calf seduto tra i candidati intercambiabili. Principio `P-GLUTE-EXERCISE-EQUIVALENCE` (Plotkin 2023: hip thrust e squat danno una crescita dei glutei simile): hip thrust, ponte, pull-through e affondi sono candidati intercambiabili. Tutti i principi sono provvisori. Nessun numero nuovo, nessuno split nuovo.

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
