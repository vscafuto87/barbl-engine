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

## Stato della versione 0.6.0

- **Copertura**: tre template, `upper_lower_4d` (4 giorni) e `full_body_3d` (3 giorni) per gli obiettivi massa, entrambi e forza, e `ppl_ul_5d` (5 giorni) per massa ed entrambi, con esercizi per le tre palestre del profilo (completa, casa, solo manubri). Massa ed entrambi usano la prescrizione `muscle_gain` (3 minuti per serie): a 3 e 4 giorni le sedute arrivano a 19 serie e sono coperte da 60 minuti in su; a 5 giorni hanno al massimo 15 serie e sono coperte anche a 45 minuti. La forza usa la prescrizione `strength` (4 minuti per serie per i recuperi più lunghi, sedute fino a 18 serie: coperta da 75 minuti in su). Restano scoperti: forza a 5 giorni (per obiettivo), 45 minuti a 3 e 4 giorni per ogni obiettivo (per scelta: in 15 serie a seduta non c'è il volume minimo), 60 minuti per la forza.
- **Template a 5 giorni** (`ppl_ul_5d`, KB 0.6.0): Upper, Lower, riposo, Push, Pull, Gambe (lunedì, martedì, giovedì, venerdì, sabato), scelta di design `P-SPLIT-PPL-UL-5D` con l'ordine della settimana preso dalla fonte di struttura. Push, Pull e Gambe hanno 13 serie, Upper e Lower 15. Petto, dorso, quadricipiti, bicipiti, tricipiti, spalle, femorali e glutei hanno almeno 10 serie frazionarie; i polpacci 6 (`C-CALVES-BAND`). Caso d'oro 04 (5 giorni, 45 minuti, `golden/profile-5d-45min.json`).
- **Esercizi per spalle e glutei** (KB 0.6.0): pattern `lateral_raise`, `rear_delt_fly` e `hip_extension` (isolamenti) con alzate laterali e posteriori (manubri e cavi) e hip thrust (bilanciere e manubrio). Il vocabolario dei muscoli non distingue i capi del deltoide: le alzate contano sulle spalle (`shoulders`).
- **Prescrizione forza**: principale 3 × 3-5, secondari 3 × 4-6, complementari 3 × 8-12, recuperi da 90 s a 4 minuti; numeri, principi e calcolo della durata nelle `notes` di `prescriptions/strength.yaml`. I template sono gli stessi della massa: il volume è sopra quello utile per la forza e la quota di serie pesanti sotto i due terzi (`C-STRENGTH-VOLUME`); i recuperi lunghi sono in conflitto aperto con il dato ACSM (`C-REST-STRENGTH`). Caso d'oro 03 (4 giorni, 75 minuti, `golden/profile-4d-strength.json`).
- **Valori**: tutti provvisori, ripresi dal piano fisso dell'app; nessun principio è ancora confermato da un coach.
- **Differenze dal piano fisso**: Upper A e Lower A partono dagli stessi esercizi; gli slot che nel piano fisso erano «da definire» sono riempiti; le ripetizioni seguono il ruolo dello slot (la panca passa da 8 fisse a 6-8, il rematore da 10-12 a 8-12); la military press resta a 6-8 con un `repsOverride` motivato, perché il carico noto del profilo d'esempio è per 7 ripetizioni.
- **Punto aperto per il motore**: quando le ripetizioni del carico noto non stanno nell'intervallo prescritto, il carico va convertito (per esempio con la formula di Epley). L'app oggi ignora le ripetizioni di `knownLoads` (`TODO(fase-14)`): la regola va scritta qui prima di implementarla.
- **Carico da chiedere (`askLoad`)**: campo booleano facoltativo di uno slot del template. Dice al motore che per quello slot l'app deve chiedere il carico di partenza alla persona (esercizi chiave: panca, rematore e military press di Upper A, squat di Lower A).
- **Motivazione valida per ogni esercizio (`everyExercise`)**: campo booleano facoltativo di una motivazione di livello `set` (oggi `PROG-DOUBLE`, `PROG-RIR-CORRECTION`, `RECORD-EPLEY`). Il motore le allega a ogni esercizio del piano come `rules`. Il validatore rifiuta il campo su livelli diversi da `set` e rifiuta una KB in cui nessuna motivazione lo ha.
- **Polpacci**: nel template a 4 giorni hanno un solo esercizio da 3 serie a settimana, in quello a 5 giorni due (6 serie), in quello a 3 giorni nessuno: sotto la fascia del principio sul volume minimo; il punto è registrato come conflitto aperto `C-CALVES-BAND`, da decidere con il coach.
- **Casi d'oro**: il caso 01 del contratto, il caso 02 (3 giorni, principiante, `golden/profile-3d.json`), il caso 03 (forza) e il caso 04 (5 giorni a 45 minuti) passano il controllo statico del validatore (serie frazionarie, durata, carichi iniziali) e il controllo del motore (`eval`).
- **Template a 3 giorni**: lo split full body è una scelta di design (principio `P-SPLIT-FULL-BODY-3D`), non ripresa da una fonte. I polpacci non hanno uno slot (vedi `C-CALVES-BAND`). Con la palestra a soli manubri alcuni slot ripetono lo stesso esercizio in sedute diverse.

La matrice di 324 profili che controlla copertura e proprietà dei piani generati è descritta in `docs/eval-matrice.md`.

## Comandi

```bash
pip install -r kb/requirements.txt
python3 kb/tools/validate.py
python3 kb/tools/validate.py --sources-md ../barbl-sources/md   # cerca frasi copiate dai libri
```
