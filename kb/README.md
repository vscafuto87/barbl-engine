# kb

Knowledge base dei piani di allenamento di Barbl. `barbl-engine` la legge come dati e produce piani conformi al contratto dell'app (`docs/contratto/` nel repository `barbl`, `schemaVersion` 3.0).

La KB non contiene testo di libri o programmi: solo regole, parametri e template scritti con parole nostre, ognuno con il riferimento alla sua fonte. Le regole di lavoro sono nel `CLAUDE.md` della radice del repository.

## Come la usa il motore

| Passo del motore | File letti |
| --- | --- |
| 1. Sceglie il template dai giorni e dall'obiettivo del profilo | `kb/templates/` |
| 2. Riempie ogni slot con il primo candidato disponibile nella palestra | `kb/exercises/`, `kb/vocab/equipment.yaml` |
| 3. Prescrive serie, ripetizioni e recuperi per ruolo e controlla la durata | `kb/prescriptions/` |
| 4. Imposta i carichi iniziali: `knownLoads` del profilo o serie di prova | `kb/exercises/` (`loading`), `kb/parameters/trialLoad.yaml` |
| 5. Scrive mesociclo, `parameters` e motivazioni con le fonti | `kb/parameters/`, `kb/rationales/`, `kb/principles/`, `kb/sources/` |
| 6. Controlla il piano: contratto, fascia di volume, casi d'oro | `kb/contract/`, `kb/golden/` |

Il volume per muscolo si conta in modo frazionario (`kb/vocab/muscles.yaml`, `setWeights`): una serie vale 1 sul muscolo primario e 0,5 sui secondari. Nel piano `muscles` resta l'elenco ordinato con il primario per primo, come oggi.

## Stato della versione 0.4.0

- **Copertura**: due template, `upper_lower_4d` (4 giorni) e `full_body_3d` (3 giorni, sedute da al massimo 18 serie: richiede almeno 54 minuti per seduta, quindi vale per le durate da 60 minuti in su), entrambi per obiettivo massa o entrambi, con esercizi per le tre palestre del profilo (completa, casa, solo manubri). Restano scoperti: 5 giorni, 45 minuti sui 3 giorni, obiettivo forza.
- **Valori**: tutti provvisori, ripresi dal piano fisso dell'app; nessun principio è ancora confermato da un coach.
- **Differenze dal piano fisso**: Upper A e Lower A partono dagli stessi esercizi; gli slot che nel piano fisso erano «da definire» sono riempiti; le ripetizioni seguono il ruolo dello slot (la panca passa da 8 fisse a 6-8, il rematore da 10-12 a 8-12); la military press resta a 6-8 con un `repsOverride` motivato, perché il carico noto del profilo d'esempio è per 7 ripetizioni.
- **Punto aperto per il motore**: quando le ripetizioni del carico noto non stanno nell'intervallo prescritto, il carico va convertito (per esempio con la formula di Epley). L'app oggi ignora le ripetizioni di `knownLoads` (`TODO(fase-14)`): la regola va scritta qui prima di implementarla.
- **Carico da chiedere (`askLoad`)**: campo booleano facoltativo di uno slot del template. Dice al motore che per quello slot l'app deve chiedere il carico di partenza alla persona (esercizi chiave: panca, rematore e military press di Upper A, squat di Lower A).
- **Motivazione valida per ogni esercizio (`everyExercise`)**: campo booleano facoltativo di una motivazione di livello `set` (oggi `PROG-DOUBLE`, `PROG-RIR-CORRECTION`, `RECORD-EPLEY`). Il motore le allega a ogni esercizio del piano come `rules`. Il validatore rifiuta il campo su livelli diversi da `set` e rifiuta una KB in cui nessuna motivazione lo ha.
- **Polpacci**: nel template hanno un solo esercizio da 3 serie a settimana, sotto la fascia del principio sul volume minimo; il punto è registrato come conflitto aperto `C-CALVES-BAND`, da decidere con il coach.
- **Casi d'oro**: il caso 01 del contratto e il caso 02 (3 giorni, principiante, `golden/profile-3d.json`) passano il controllo statico del validatore (serie frazionarie, durata, carichi iniziali) e il controllo del motore (`eval`).
- **Template a 3 giorni**: lo split full body è una scelta di design (principio `P-SPLIT-FULL-BODY-3D`), non ripresa da una fonte. I polpacci non hanno uno slot (vedi `C-CALVES-BAND`). Con la palestra a soli manubri alcuni slot ripetono lo stesso esercizio in sedute diverse.

La matrice di 324 profili che controlla copertura e proprietà dei piani generati è descritta in `docs/eval-matrice.md`.

## Comandi

```bash
pip install -r kb/requirements.txt
python3 kb/tools/validate.py
python3 kb/tools/validate.py --sources-md ~/Progetti/app-palestra/sources/md   # cerca frasi copiate dai libri
```
