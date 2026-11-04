# Eval a matrice di profili

`engine/test/flow/profile_matrix_test.dart` genera 324 profili validi dagli enum di `kb/contract/profile.schema.json` e li passa a `generatePlan` con la KB vera:

- giorni 3, 4, 5; durate 45, 60, 75, 90; obiettivi `muscle_gain`, `strength`, `both`;
- palestre `full`, `home`, `dumbbells`, con l'attrezzatura di `kb/vocab/equipment.yaml` (`gymTypes`);
- livelli `under_6_months` (nessun carico noto), `6_months_2_years` (panca 80 kg e squat «Non lo so»), `over_2_years` (quattro carichi noti).

Il motore non cambia: la matrice misura, non corregge.

## Cosa verifica

Per ogni profilo, `generatePlan` non lancia e dà o un rifiuto `NotCovered` (motivo di `NotCoveredReason`, dettaglio non vuoto) o un piano che:

1. valida contro `kb/contract/plan.schema.json` e ha `schemaVersion` `3.0`;
2. ha ogni seduta con durata stimata entro `sessionDurationMin`;
3. non usa esercizi che richiedono attrezzatura assente dalla palestra;
4. ha una motivazione per ogni regola citata dagli esercizi;
5. ha `initialLoad` coerente: con un carico noto `source: profile` e quei kg; senza, `kg` nullo con `trial_set` o `manual`; `trial_set` solo se l'esercizio lo ammette nella KB; stesso carico in tutte le occorrenze dello stesso esercizio;
6. ha `name.it` e `name.en` per ogni esercizio;
7. raggiunge per petto, dorso, quadricipiti, bicipiti e tricipiti la soglia di serie frazionarie settimanali di `parameters/belowBand` (`bandMin`, alimentata da `P-VOL-MIN-10`); i deficit noti sono in `_knownDeficits` (oggi i polpacci, `C-CALVES-BAND`);
8. è identico, come JSON, generandolo due volte dallo stesso profilo.

Un test a parte confronta la copertura con la mappa esplicita `_expectedCoverage` (giorni, obiettivo, durata → `covered` o motivo) e stampa la tabella. Se la KB cambia la copertura, il test fallisce finché la mappa non si aggiorna di proposito.

## Aggiungere una proprietà

Aggiungere il controllo in `_planViolations` (una riga di violazione per caso). Se una combinazione la viola, non si cambia il motore in questa sede: si riporta il caso e si mette la chiave del profilo in `_skipped` con il motivo; il test di quella combinazione risulta saltato.

## Copertura attuale

Uguale per ogni palestra e livello (nessun rifiuto per attrezzatura: i template sono coperti in tutte e tre le palestre).

| Giorni | Obiettivo | 45 min | 60 min | 75 min | 90 min |
| --- | --- | --- | --- | --- | --- |
| 3 | muscle_gain | duration | covered | covered | covered |
| 3 | strength | goal | goal | goal | goal |
| 3 | both | duration | covered | covered | covered |
| 4 | muscle_gain | duration | covered | covered | covered |
| 4 | strength | goal | goal | goal | goal |
| 4 | both | duration | covered | covered | covered |
| 5 | qualsiasi | days | days | days | days |

Totali (324 profili): 108 `covered`, 36 `duration`, 72 `goal`, 108 `days`. Nessun `equipment`.

## Osservazioni sul volume (fuori dalle proprietà controllate)

Calcolate sui piani generati (serie frazionarie settimanali), non fanno fallire il test:

- 3 giorni: polpacci senza slot; femorali 6; spalle 3; deltoidi anteriori 5; glutei 6,5 (`full`) o 8 (`home`, `dumbbells`).
- 4 giorni: polpacci 3 (`C-CALVES-BAND`); spalle 3; deltoidi anteriori 4; glutei 7 (`full`) o 11,5; femorali 10.
- I cinque muscoli controllati stanno tra 10 e 13 serie; petto, dorso e quadricipiti a 3 giorni sono esattamente alla soglia (10).

## Casi `skip`

Nessuno: i 324 profili rispettano le proprietà.
