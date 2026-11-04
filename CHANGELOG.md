# Changelog

Versioni della knowledge base (`kb/VERSION`, semver). Ogni modifica che cambia un piano generato alza la versione. Il tag di rilascio ha la forma `vX.Y.Z` e coincide con `kb/VERSION` (lo controlla la CI quando si crea un tag).

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
