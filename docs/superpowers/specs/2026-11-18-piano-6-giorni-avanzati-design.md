# Piano a 6 giorni per il livello avanzato

Data: 18 novembre 2026. Richiesta di Vincenzo («Procedi con il primo punto dei prossimi sviluppi»), annunciata il 15 novembre come lavoro successivo al livello avanzato (`2026-11-15-livello-avanzato-design.md`). Riguarda `barbl-engine` (KB e motore) e `barbl` (contratto e app).

## Intento

Chi si allena da più di 2 anni (`experience: over_2_years`) può scegliere 6 sedute a settimana e riceve un piano avanzato a 6 giorni, con le stesse regole dei piani avanzati a 3, 4 e 5 giorni: cedimento sull'ultima serie di isolamenti e complementari (mai multiarticolari pesanti), drop set e myo-reps sugli isolamenti, superset, RIR 2 → 1 → 1 → 0 e scarico. La scelta vale in onboarding e in «Cambia piano».

## Obiettivi

- Profilo con `daysPerWeek: 6`, ammesso solo con `experience: over_2_years` (controllo dell'app; il motore risponde «non coperto» agli altri).
- Un template `advanced_ppl_6d` nella KB, per ogni obiettivo (`muscle_gain`, `both`, `strength`), palestra e durata già coperti dai template avanzati.
- Onboarding e «Cambia piano»: il passo dell'esperienza viene **prima** di quello dei giorni (scelta di Vincenzo del 18/11/2026); la scheda «6» compare solo con «Più di 2 anni».
- Tutte le schermate che mostrano la settimana (Oggi, Piano, anteprima, promemoria, recupero delle sedute) reggono 6 sedute.

## Non obiettivi

- Piani a 6 giorni per principianti e intermedi.
- 7 giorni.
- Cambi alle regole di progressione o al contratto del piano (resta `3.3`).
- Nessuna regola nuova in `docs/logica-progressione.md`.

## Anti-obiettivi

- Una persona non avanzata che sceglie «6» e poi riceve il piano fisso di ricaduta.
- Un muscolo allenato in due giorni consecutivi come primario (il recupero minimo dei `parameters` resta un vincolo).
- Sedute che sforano la durata scelta.
- Numeri di dominio nel codice, testo copiato dalle fonti, nomi di programmi commerciali.

## Approcci considerati

Per l'offerta dei 6 giorni (deciso da Vincenzo il 18/11/2026):

1. **Esperienza prima dei giorni** — scelto. La scheda «6» compare solo per chi è avanzato; nessuno sceglie un'opzione che poi gli viene tolta.
2. «6» sempre visibile, con un avviso se poi l'esperienza è sotto i 2 anni e ritorno al passo dei giorni: un passo indietro forzato.
3. 6 giorni per tutti: un template in più per intermedi, fuori dalla richiesta.

Per la struttura della settimana (proposta nostra, nessuna obiezione di Vincenzo):

1. **Push / Pull / Gambe × 2** — scelto. È la struttura dei programmi a 6 giorni delle fonti interne (un Push/Pull/Legs 6× e un powerbuilding 5–6×, solo come riferimento di struttura), dà ogni muscolo due volte a settimana con 72 ore tra le due, e il recupero tra sedute consecutive è rispettato perché i primari cambiano ogni giorno.
2. Upper / Lower × 3: tre volte a settimana per muscolo, sedute più lunghe e recupero di 24 ore tra Upper e Upper nella stessa settimana solo con giorni fissi; meno variato.
3. Upper / Lower + Push / Pull / Gambe + un giorno di richiamo: ibrido, difficile da tenere nella fascia di volume.

## Design

### KB (`barbl-engine/kb`)

- **Template** `kb/templates/advanced_ppl_6d.yaml`: `split: push_pull_legs`, `daysPerWeek: 6`, `goals: [muscle_gain, both, strength]`, `experience: [over_2_years]`, `defaultSchedule` lunedì–sabato: push_a, pull_a, legs_a, push_b, pull_b, legs_b.
  - **Giro A** più pesante: multiarticolari principali nelle prescrizioni basse, poi complementari e isolamenti con le tecniche.
  - **Giro B** più «pump»: multiarticolari diversi (inclinata, manubri, macchine) come principale, più isolamenti e superset.
  - Sedute più corte di quelle a 5 giorni (meno esercizi ciascuna), perché il volume settimanale si divide su 6 sedute e resta nella fascia (P-VOL-*, C-ADVANCED-VOLUME). Il builder controlla il volume settimanale per muscolo con il calcolo del motore e lo registra nel CHANGELOG.
  - Tecniche dichiarate negli slot come negli altri template avanzati (`lastSet`), con le stesse regole del validatore: mai su `main` né sugli esercizi `noFailure`, `drop_set` e `myo_reps` solo su isolamenti in blocco singolo, al massimo `maxTechniquesPerSession` per seduta.
  - Il finisher degli addominali resta due volte a settimana (P-CORE-FINISHER): uno nel giro A e uno nel giro B, in due sedute non consecutive.
  - Gambe: lo `hinge` sta nella seduta delle gambe, non nel Pull, così Pull e Gambe consecutivi non condividono femorali e glutei come primari.
- **Fonti**: le stesse dei template avanzati, più i due programmi interni a 6 giorni (solo struttura, titolo e pagina) e i principi di frequenza esistenti (P-FREQ-MIN-2, P-FREQ-HYP-NEUTRAL). Se serve un principio nuovo («6 sedute a settimana solo per chi è avanzato») è di tipo `design`, `provisional`.
- **Golden**: profili avanzati a 6 giorni per ogni obiettivo, palestra e durata (45, 60, 75, 90), più un profilo intermedio a 6 giorni che deve risultare «non coperto». Proprietà: le stesse degli altri template avanzati, più nessun muscolo primario in due giorni consecutivi del calendario predefinito.
- `kb/VERSION` 0.33.0, voce nel CHANGELOG.

### Contratto del profilo (`barbl/docs/contratto/`, profilo 1.6)

- `daysPerWeek` ammette `6`. Il modello scrive `schemaVersion` `1.6` solo quando `daysPerWeek` è 6 (come per gli altri campi facoltativi); i profili salvati prima si leggono come oggi.
- Copia dello schema nel motore (`kb/contract/`, `SOURCE.md`).

### Motore (`barbl-engine/engine`)

- Il lettore del profilo ammette 6 e la versione 1.6. `select_template` non cambia: con 6 giorni e un'esperienza diversa da `over_2_years` non c'è un template senza `experience`, quindi il risultato è `NotCovered`.
- Nessuna altra modifica attesa: `fit_to_duration`, `extend_to_duration`, enfasi e varietà (`variantSeed`) valgono come per gli altri template. Se un passo assume al più 5 sedute, il builder lo sistema e lo dice nella PR.

### App (`barbl`)

- **Dominio** (`packages/progression`): `daysPerWeekChoices` diventa `[3, 4, 5, 6]` (un test lo tiene uguale allo schema) e una funzione pura dice quali scelte valgono per un'esperienza (`daysPerWeekChoicesFor(experience)`: 6 solo con `over_2_years`). Il numero che separa i 6 giorni non è nel codice come soglia di dominio: è la lista delle scelte, come le altre di `profile_choices.dart`. `Profile` ammette 6 e scrive `1.6` solo con 6.
- **Onboarding** (`features/onboarding/`): ordine dei passi goal → gym → **experience → schedule** → emphasis → loads → notifications → finish (anche in «Cambia piano», che non ha il passo delle notifiche). Il passo dei giorni mostra le schede di `daysPerWeekChoicesFor`; se l'esperienza cambia e il numero scelto non è più ammesso, numero e giorni della settimana si azzerano (in «Cambia piano» con un profilo a 6 giorni che passa a «Da 6 mesi a 2 anni»). La griglia dei giorni della settimana (4 + 3) regge 6 scelte senza cambi.
- **Schede del passo dei giorni**: con quattro schede il layout deve reggere 320 punti e il testo a 1,3 in inglese (skill Taste e Impeccable, token esistenti). Proposta: stessa riga a schede uguali se ci stanno, altrimenti griglia 2 × 2.
- **Riepilogo e passo finale**: nessun testo nuovo oltre a quello che viene dal piano; il riepilogo mostra sei righe della settimana.
- **Settimana con 6 sedute**: verifica con test di Oggi, Piano (mappa del mesociclo e righe), anteprima, promemoria, recupero delle sedute e avvisi di Avvio (`startWarnings`, recupero minimo) con il calendario lunedì–sabato.
- **Motore**: `tool/update_engine.dart` al commit della KB 0.33.0; flusso `test/app/` con onboarding «Più di 2 anni» → 6 giorni → piano del motore con sei sedute e tecniche; e un caso «Da 6 mesi a 2 anni» senza la scheda «6».
- **Documenti**: `docs/architettura.md`, `docs/decisioni.md` (ordine dei passi, 6 giorni solo per avanzati), `docs/specifiche-ux-ui.md` (passo dei giorni), contratto.

## Lasciato al builder

- Esercizi, candidati, prescrizioni e tecniche di ogni slot delle sei sedute, dai programmi della KB e dal catalogo (153 esercizi), con il volume nella fascia.
- Il layout preciso delle quattro schede del passo dei giorni.
- Ordine delle pull request: (1) app, contratto del profilo 1.6; (2) engine, KB 0.33.0 e motore; (3) app, dominio, onboarding, motore aggiornato e test.

## Scelte nostre da controllare

1. Push/Pull/Gambe × 2 con giro A pesante e giro B «pump», lunedì–sabato, domenica di riposo.
2. `1.6` scritto solo con 6 giorni.
3. Chi passa da 6 giorni a un'esperienza non avanzata in «Cambia piano» rifà la scelta dei giorni (nessun avviso a parte: la scheda «6» non c'è più e il passo è da completare).
