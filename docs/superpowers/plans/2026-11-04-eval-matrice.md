# Eval a matrice di profili — piano

**Obiettivo:** misurare, senza giudicare a occhio, che `generatePlan` dia per ogni profilo valido o un piano che rispetta le proprietà attese o un rifiuto «non coperto» motivato, mai un'eccezione. Il motore non cambia comportamento; si aggiunge il controllo.
**Verifica:** CI (`dart analyze`, `dart test`, `dart run barbl_engine eval --kb ../kb`, `python3 kb/tools/validate.py`). Qui non c'è Dart: scrivere con cura e correggere sulla CI. Repo `/home/claude/barbl-engine`, ramo `feature/eval-matrice`; leggere prima il `CLAUDE.md` della radice.

## Vincoli
- Nessun numero di dominio nel codice di `lib/`; i test possono leggere le soglie dalla KB reale (`kb/`) e dai `parameters`, non scriverle a mano. Le dimensioni della matrice vengono dall'enum dello schema del profilo (`kb/contract/profile.schema.json`): giorni 3/4/5, durate 45/60/75/90, obiettivi `muscle_gain`/`strength`/`both`, palestre `full`/`home`/`dumbbells`, esperienza (tre valori), con `knownLoads` vuoti e, per alcuni profili, con un carico noto.
- Test determinati e deterministici. Commit in italiano, mai su `main`, nessuna PR da aprire.

## Task 1 — Test a matrice: `engine/test/flow/profile_matrix_test.dart`
Per ogni combinazione (3×4×3×3×3 = 324 profili, generati dagli enum) con la KB reale:
1. `generatePlan` non lancia.
2. Esito `Ok`: il piano valida contro `kb/contract/plan.schema.json` (come fa già l'eval); `schemaVersion` `3.0`; ogni seduta ha durata stimata ≤ `sessionDurationMin`; nessun esercizio richiede attrezzatura assente dal profilo; ogni `rules` ha la sua motivazione; ogni esercizio con `askLoad` ha `initialLoad` coerente con la tabella (kg numero con `profile`, `kg` nullo con `trial_set`/`manual`); ogni esercizio ha `name.it` e `name.en`; lo stesso profilo dà lo stesso piano due volte (determinismo, confronto del JSON).
3. Volume: per ogni muscolo tra petto, schiena, quadricipiti, bicipiti, tricipiti, serie frazionarie settimanali ≥ la soglia del principio `P-VOL-MIN-10` (leggerla dalla KB/`belowBand`, non scriverla); i muscoli in deficit noti (polpacci, conflitto `C-CALVES-BAND`) sono elencati in una lista esplicita nel test con il riferimento al conflitto.
4. Esito `Rejected`: il motivo è uno di `NotCoveredReason` (giorni, obiettivo, durata...) e il messaggio non è vuoto.
5. Report: il test stampa una tabella riassuntiva (quanti profili coperti / non coperti per motivo) e **fallisce se la copertura attesa cambia senza accorgersene**: una mappa esplicita (giorni, obiettivo, durata → coperto o motivo) nel test, che oggi dice: 4 giorni coperti per massa/entrambi, 3 giorni coperti per massa/entrambi da 60 minuti in su, tutto il resto non coperto. Verificarla leggendo il comportamento reale prima di fissarla (eseguire con ragionamento sul codice, non indovinare).
Se un profilo dà un'eccezione o viola una proprietà: NON modificare il motore in questa PR; riportare il caso nel report e lasciare il test su quella combinazione marcato `skip` con il motivo.

## Task 2 — Documento
`docs/eval-matrice.md`: cosa verifica la matrice, come aggiungere una proprietà, tabella della copertura attuale (copiata dall'output del test), elenco dei casi `skip`. Collegarlo dal `CLAUDE.md`? No: solo da `kb/README.md` in una riga. Push e CI verde.
