# kb

Knowledge base dei piani di allenamento di Barbl. `barbl-engine` la legge come dati e produce piani conformi al contratto dell'app (`docs/contratto/` nel repository `barbl`, `schemaVersion` 2.0).

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

## Stato della versione 0.3.0

- **Copertura**: un template, `upper_lower_4d` (4 giorni, obiettivo massa o entrambi), con esercizi per le tre palestre del profilo (completa, casa, solo manubri). Profili a 3 o 5 giorni e obiettivo forza non sono ancora coperti.
- **Valori**: tutti provvisori, ripresi dal piano fisso dell'app; nessun principio è ancora confermato da un coach.
- **Differenze dal piano fisso**: Upper A e Lower A partono dagli stessi esercizi; gli slot che nel piano fisso erano «da definire» sono riempiti; le ripetizioni seguono il ruolo dello slot (la panca passa da 8 fisse a 6-8, il rematore da 10-12 a 8-12); la military press resta a 6-8 con un `repsOverride` motivato, perché il carico noto del profilo d'esempio è per 7 ripetizioni.
- **Punto aperto per il motore**: quando le ripetizioni del carico noto non stanno nell'intervallo prescritto, il carico va convertito (per esempio con la formula di Epley). L'app oggi ignora le ripetizioni di `knownLoads` (`TODO(fase-14)`): la regola va scritta qui prima di implementarla.
- **Carico da chiedere (`askLoad`)**: campo booleano facoltativo di uno slot del template. Dice al motore che per quello slot l'app deve chiedere il carico di partenza alla persona (esercizi chiave: panca, rematore e military press di Upper A, squat di Lower A).
- **Motivazione valida per ogni esercizio (`everyExercise`)**: campo booleano facoltativo di una motivazione di livello `set` (oggi `PROG-DOUBLE`, `PROG-RIR-CORRECTION`, `RECORD-EPLEY`). Il motore le allega a ogni esercizio del piano come `rules`. Il validatore rifiuta il campo su livelli diversi da `set` e rifiuta una KB in cui nessuna motivazione lo ha.
- **Polpacci**: nel template hanno un solo esercizio da 3 serie a settimana, sotto la fascia del principio sul volume minimo; il punto è registrato come conflitto aperto `C-CALVES-BAND`, da decidere con il coach.
- **Casi d'oro**: il caso 01 del contratto passa il controllo statico del validatore (serie frazionarie, durata, carichi iniziali); il controllo vero lo farà il motore.

## Comandi

```bash
pip install -r kb/requirements.txt
python3 kb/tools/validate.py
python3 kb/tools/validate.py --sources-md ~/Progetti/app-palestra/sources/md   # cerca frasi copiate dai libri
```
