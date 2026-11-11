# Eval a matrice di profili

`engine/test/flow/profile_matrix_test.dart` genera 324 profili validi dagli enum di `kb/contract/profile.schema.json` e li passa a `generatePlan` con la KB vera:

- giorni 3, 4, 5; durate 45, 60, 75, 90; obiettivi `muscle_gain`, `strength`, `both`;
- palestre `full`, `home`, `dumbbells`, con l'attrezzatura di `kb/vocab/equipment.yaml` (`gymTypes`);
- livelli `under_6_months` (nessun carico noto), `6_months_2_years` (panca 80 kg e squat «Non lo so»), `over_2_years` (quattro carichi noti).

Il motore non cambia: la matrice misura, non corregge.

In più c'è la **matrice dell'enfasi** (756 profili): stessi giorni, durate, obiettivi e palestre, un solo livello (`6_months_2_years`, l'enfasi non dipende dai carichi noti) e sette varianti di `emphasis` (profilo `1.2`): `glutes_hamstrings`, `shoulders`, `arms`, `quadriceps`, `chest`, `back` e la coppia `glutes_hamstrings` + `arms`. La variante «nessuna» è la matrice di base.

## Cosa verifica

Per ogni profilo, `generatePlan` non lancia e dà o un rifiuto `NotCovered` (motivo di `NotCoveredReason`, dettaglio non vuoto) o un piano che:

1. valida contro `kb/contract/plan.schema.json` e ha `schemaVersion` `3.0`;
2. ha ogni seduta con durata stimata entro `sessionDurationMin`;
3. non usa esercizi che richiedono attrezzatura assente dalla palestra;
4. ha una motivazione per ogni regola citata dagli esercizi;
5. ha `initialLoad` coerente: con un carico noto `source: profile` e quei kg; senza, `kg` nullo con `trial_set` o `manual`; `trial_set` solo se l'esercizio lo ammette nella KB; stesso carico in tutte le occorrenze dello stesso esercizio;
6. ha `name.it` e `name.en` per ogni esercizio;
7. per gli obiettivi `muscle_gain` e `both`, raggiunge per petto, dorso, quadricipiti, bicipiti e tricipiti la soglia di serie frazionarie settimanali di `parameters/belowBand` (`bandMin`, alimentata da `P-VOL-MIN-10`); a 5 giorni anche per spalle, femorali e glutei (`_extraVolumeMusclesByDays`); i deficit noti sono in `_knownDeficits` (oggi i polpacci, `C-CALVES-BAND`). Per `strength` la soglia non si controlla: è dell'ipertrofia, per la forza il volume utile è molto più basso (`P-VOL-DOSE-STR`) e il principale a 3 serie porta petto, dorso e quadricipiti a 9 (`C-STRENGTH-VOLUME`);
8. propone la serie di prova solo se le ripetizioni minime dell'esercizio più il RIR più alto delle settimane di carico restano entro `maxRepsPlusRir` di `parameters/trialLoad`;
9. è identico, come JSON, generandolo due volte dallo stesso profilo.

Per i profili con enfasi valgono le stesse proprietà, più:

10. la copertura è la stessa del profilo senza enfasi (stesso esito, stesso motivo di rifiuto);
11. le serie frazionarie settimanali di ogni muscolo del distretto (`muscles` di `kb/emphasis/<id>.yaml`) non sono sotto quelle del piano senza enfasi;
12. in ogni seduta gli esercizi con la regola `EMPHASIS` non superano i posti delle enfasi del profilo, e un posto non applicato si spiega con la durata: la seduta, con le serie di uno slot complementare in più, supererebbe `sessionDurationMin`.

Dalla KB 0.25.0 valgono anche (`engine/test/flow/extensions_test.dart`, tutti i 108 profili di base per ogni livello di durata):

13. nessun muscolo supera `bandMax` di `parameters/belowBand` (16 serie frazionarie a settimana);
14. con più tempo le serie totali e le estensioni non diminuiscono (le estensioni non dipendono dalla durata, tranne per il tempo che lasciano);
15. a 60 minuti, massa e palestra completa, le spalle hanno almeno 6 serie frazionarie (3 e 4 giorni) e i polpacci almeno 3 (3 giorni);
16. un principiante (`under_6_months`) ha RIR 3, 3, 2, 2 e scarico 4, e nessun esercizio con `technicalDemand: high`; gli altri livelli 3, 3, 2, 1 e 4;
17. la regola `TIME-EXTEND` e la sua motivazione compaiono nel piano solo se almeno un esercizio è un'estensione.

Un test a parte confronta la copertura con la mappa esplicita `_expectedCoverage` (giorni, obiettivo, durata → `covered` o motivo) e stampa la tabella. Se la KB cambia la copertura, il test fallisce finché la mappa non si aggiorna di proposito.

## Aggiungere una proprietà

Aggiungere il controllo in `_planViolations` (una riga di violazione per caso). Se una combinazione la viola, non si cambia il motore in questa sede: si riporta il caso e si mette la chiave del profilo in `_skipped` con il motivo; il test di quella combinazione risulta saltato.

## Copertura attuale

Uguale per ogni palestra e livello (nessun rifiuto per attrezzatura: i template sono coperti in tutte e tre le palestre).

| Giorni | Obiettivo | 45 min | 60 min | 75 min | 90 min |
| --- | --- | --- | --- | --- | --- |
| 3 | muscle_gain | duration | covered | covered | covered |
| 3 | strength | duration | duration | covered | covered |
| 3 | both | duration | covered | covered | covered |
| 4 | muscle_gain | duration | covered | covered | covered |
| 4 | strength | duration | duration | covered | covered |
| 4 | both | duration | covered | covered | covered |
| 5 | muscle_gain | covered | covered | covered | covered |
| 5 | strength | goal | goal | goal | goal |
| 5 | both | covered | covered | covered | covered |

Totali (324 profili): 216 `covered`, 72 `duration`, 36 `goal`. Nessun `days` (dalla KB 0.6.0 c'è il template a 5 giorni `ppl_ul_5d`, solo per massa ed entrambi) e nessun `equipment`. Il 5 giorni copre anche i 45 minuti perché le sue sedute hanno al massimo 15 serie; 3 e 4 giorni a 45 minuti restano non coperti per durata, per scelta: in sedute da 15 serie non c'è spazio per il volume minimo con tre o quattro sedute.

## Conteggi dell'enfasi

Il test `conteggi dell'enfasi` stampa e confronta con `_expectedEmphasis` i posti applicati sul totale dei posti per template e durata (profili coperti, tutte le palestre e gli obiettivi coperti, quattro varianti):

| Template | 45 min | 60 min | 75 min | 90 min |
| --- | --- | --- | --- | --- |
| `full_body_3d` | non coperto | 42/60 | 81/90 | 90/90 |
| `upper_lower_4d` | non coperto | 24/60 | 72/90 | 90/90 |
| `ppl_ul_5d` | 0/48 | 48/48 | 48/48 | 48/48 |

Dei 288 profili coperti con enfasi, 219 hanno tutti i posti applicati, 27 alcuni e 42 nessuno, sempre per durata: i 24 a 5 giorni da 45 minuti (sedute già a 13 e 15 serie), i 12 a 4 giorni da 60 minuti con spalle o braccia (le sedute Upper hanno 19 serie) e i 6 di forza a 4 giorni da 75 minuti con spalle o braccia (Upper a 18 serie da 4 minuti). Nella palestra a soli manubri ogni posto ha un esercizio disponibile.

## Osservazioni sul volume (fuori dalle proprietà controllate)

Calcolate sui piani generati (serie frazionarie settimanali), non fanno fallire il test:

- 3 giorni: polpacci senza slot; femorali 6; spalle 3; deltoidi anteriori 5; glutei 6,5 (`full`) o 8 (`home`, `dumbbells`).
- 4 giorni: polpacci 3 (`C-CALVES-BAND`); spalle 3; deltoidi anteriori 4; glutei 7 (`full`) o 11,5; femorali 10.
- 5 giorni (uguale in ogni palestra salvo i glutei): petto 10, dorso 10, spalle 12, deltoidi anteriori 5, tricipiti 11, bicipiti 11, quadricipiti 10, femorali 10,5, glutei 11 (`full`) o 12,5 (`home`, `dumbbells`), polpacci 6 (`C-CALVES-BAND`). Sedute: Push, Pull e Gambe 13 serie, Upper e Lower 15 (39 e 45 minuti stimati).
- I cinque muscoli controllati stanno tra 10 e 13 serie; petto, dorso e quadricipiti a 3 giorni sono esattamente alla soglia (10).
- Forza (statico, palestra completa): a 4 giorni petto 9, dorso 12, quadricipiti 12, bicipiti 12, tricipiti 10,5; a 3 giorni petto, dorso e quadricipiti 9, bicipiti 10,5, tricipiti 12. Tutti sopra le circa 5 serie di `P-VOL-DOSE-STR`.

## Casi `skip`

Nessuno: i 324 profili e i 756 con enfasi rispettano le proprietà (verificato dalla CI).

## Estensioni e durate (KB 0.25.0)

Prima delle estensioni un piano da 75 o 90 minuti era quello da 60 (al massimo 57 minuti per seduta; a 5 giorni sedute da 39 a 45 minuti con ogni durata). Ora ogni seduta usa il tempo finché le estensioni e il tetto di 16 serie lo permettono. Minuti per seduta, massa e palestra completa:

| Giorni | 45 min | 60 min | 75 min | 90 min |
| --- | --- | --- | --- | --- |
| 3 | 42, 45, 39 | 60, 54, 57 | 69, 72, 75 | 78, 81, 75 |
| 4 | 39 × 4 | 57 × 4 | 75, 57, 75, 66 | 84, 57, 75, 66 |
| 5 | 39, 39, 39, 45, 45 | 57, 48, 57, 54, 54 | 57, 48, 66, 63, 54 | 57, 48, 66, 63, 54 |

Il 5 giorni ha già volume vicino al tetto (spalle 15, quadricipiti 16 a 60 minuti): da 75 a 90 minuti il piano non cambia, perché gli slot che restano porterebbero un muscolo oltre le 16 serie. Una seduta resta sotto la durata quando le estensioni disponibili sono finite o ogni muscolo che resta è al tetto: è voluto (`P-TIME-EXTEND`).

Serie frazionarie a settimana prima e dopo (massa, palestra completa, intermedio):

| Muscolo | 3 giorni, 60 min | 4 giorni, 60 min |
| --- | --- | --- |
| Spalle | 3 → 6 | 3 → 9 |
| Polpacci | 0 → 3 | 6 → 6 |
| Glutei | 6,5 → 6,5 | 7 → 10 |
| Femorali | 6 → 6 | 10 → 11,5 |
