# Durata, volume, riscaldamento ed esperienza — specifica

Data: 11 novembre 2026. KB di partenza: 0.24.0. Esito dell'analisi su 216 profili generati con il motore vero (3 obiettivi × 3 palestre × 3/4/5 giorni × 45/60/75/90 minuti × 2 livelli di esperienza) e delle scelte di Vincenzo dell'11 novembre.

## Problemi da risolvere

1. **75 e 90 minuti non servono.** `fitToDuration` sa solo togliere slot (`P-TIME-TRIM`); i template sono tarati sui 60 minuti. Un profilo massa a 90 minuti ha lo stesso piano di quello a 60 (al massimo 57 minuti); il piano a 5 giorni resta a 39–45 minuti con qualunque durata.
2. **Buchi di volume a 60 minuti.** Serie frazionarie a settimana, massa, palestra completa: spalle 3 (3 e 4 giorni), deltoide posteriore 0 (3 e 4 giorni), polpacci 0 e femorali 6 (3 giorni), glutei 6,5–7 (3 e 4 giorni). In Upper/Lower Lower A dura 39 minuti, le Upper 57.
3. **Riscaldamento specifico solo sul principale.** `warmup: true` c'è solo per il ruolo `main` (un esercizio per seduta); i multiarticolari complementari (military press, leg press, lat machine, front squat…) non ne hanno. Il commento di `kb/vocab/patterns.yaml` («la regola 12 si applica al primo multiarticolare di ogni pattern») non corrisponde al comportamento.
4. **L'esperienza non cambia il piano.** `experience` entra solo nella chiave della variante: un principiante arriva a RIR 1 in settimana 4 e può ricevere front squat, good morning o sissy squat.

## Scelte di Vincenzo (11 novembre 2026)

- Tempo in più: **slot di estensione**, non serie in più sugli stessi esercizi.
- Buchi a 60 minuti: **ribilanciare** anche i piani da 60.
- Riscaldamento: esteso ai multiarticolari complementari, **non** contato nella durata stimata (resta `minutesPerSet` × serie di lavoro).
- Principianti (`under_6_months`): **RIR minimo 2** ed **esercizi meno tecnici**. Nessuna riduzione di serie.

## Progetto

### D1. Slot di estensione (risolve 1 e 2)

- **KB**: ogni template ha un elenco facoltativo `extensions`, in **ordine di priorità sulla settimana**, con lo stesso formato dei `placements` dell'enfasi: `{ session, slot }`, dove lo slot ha `pattern`, `role` (`accessory` o `secondary`), `candidates` e, facoltativo, `equivalent`. Schema in `kb/schema/template.schema.json`, controlli nel validatore (seduta esistente, primo candidato con il pattern dello slot, almeno un candidato per ogni tipo di palestra).
- **Motore**: passo nuovo `extendToDuration` dopo `applyEmphasis` e prima di `prescribe` (le scelte esplicite della persona, l'enfasi, hanno la precedenza sul tempo). Le estensioni si valutano in ordine; ognuna entra solo se:
  1. la seduta, con le sue serie in più, resta entro `sessionDurationMin` (stessa `estimatedMinutes`);
  2. la seduta non ha già quel pattern (dal template, dall'enfasi o da un'estensione precedente);
  3. dopo l'aggiunta nessun muscolo dell'esercizio supera `bandMax` di `parameters/belowBand` nel volume frazionario della settimana (`setWeights` del vocabolario; `P-VOL-BAND-CAP`, `P-VOL-DIMINISHING`);
  4. esiste un candidato disponibile non già usato nella seduta (scelta come gli slot normali: `equivalent` e `stableHash`, escludendo gli esercizi già presenti).

  Altrimenti l'estensione si salta in silenzio. Funzione pura e deterministica; nessun numero nel codice.
- **Conseguenza dichiarata**: oltre la fascia il motore non aggiunge volume, quindi un piano a 90 minuti può restare uguale a quello a 75 e una seduta può durare meno del tempo dichiarato. Si scrive nel principio nuovo `P-TIME-EXTEND` (design, fonte `barbl-design`, con `P-VOL-BAND-CAP` e `P-VOL-DIMINISHING`) e nel README della KB.
- **Ribilanciamento a 60**: si ottiene con le stesse estensioni (a 60 minuti le sedute corte hanno spazio). I template di base non cambiano, salvo correzioni emerse dall'eval.
- **Prima proposta di estensioni** (da tarare con la matrice; il criterio sono i buchi del punto 2):
  - `upper_lower_4d`: Lower A alzate laterali → Lower B deltoide posteriore → Lower A estensione d'anca → Upper A alzate laterali → Upper B deltoide posteriore → Lower B flessione del ginocchio.
  - `full_body_3d`: Full C polpacci → Full A alzate laterali → Full B polpacci → Full C flessione del ginocchio → Full A estensione d'anca → Full B deltoide posteriore.
  - `ppl_ul_5d`: Push alzate laterali → Legs flessione del ginocchio → Upper estensione del gomito → Push isolamento petto → Lower estensione del ginocchio → Pull flessione del gomito.
- **Motivazione** (scelta di Vincenzo, 11 novembre): gli esercizi aggiunti citano la regola `TIME-EXTEND` (motivazione `level: session`, nuova in `kb/rationales/`), come `EMPHASIS`; la motivazione entra nel piano solo se almeno un esercizio la cita. Che l'app la mostri nella scheda «Seduta» del «Perché questo?» è da verificare nella fase B.

### D2. Riscaldamento sui multiarticolari (risolve 3)

- **KB**: `kb/vocab/patterns.yaml` ha già `mechanics` (`compound` / `isolation`); il bundle e `KnowledgeBase` lo leggono. Nelle prescrizioni `warmup` del ruolo diventa un valore enumerato: `always` (principale), `firstCompoundOfPattern` (complementare), `never` (isolamento). Si accettano ancora `true` e `false` come `always` e `never`, così le prescrizioni esistenti non cambiano significato.
- **Motore**: con `firstCompoundOfPattern` l'esercizio ha `warmup: true` solo se il suo pattern è `compound` e nessun esercizio precedente della seduta ha lo stesso pattern (Push: la panca sì, la chest press dopo no).
- **App**: nessun cambio. Legge già `warmup` per esercizio e applica `parameters.warmup` (sotto `minLoadKg` nessuna serie). La soglia per i manubri e l'indicazione per i carichi scritti a mano sono la fase B2 (sotto).
- **Principi**: `P-WARMUP-HEAVY` (c'è) e nuovo `P-WARMUP-SPECIFIC` (il riscaldamento specifico conta più di quello generale; fonte Ribeiro et al. 2021, `access: abstract_only` finché non si legge il testo completo). Parole nostre.
- La durata stimata non cambia (scelta di Vincenzo).

### D3. Esperienza (risolve 4)

- **RIR minimo**: `parameters/mesocycle.yaml` ha `minRirTargetByExperience: { under_6_months: 2 }`; il motore porta ogni settimana di carico a `max(rirTarget, minimo)` (le settimane di scarico non cambiano). Per un principiante: 3, 3, 2, 2, scarico 4. Il blocco `mesocycle` del piano resta nello stesso formato: nessun cambio di contratto.
  - Principio nuovo `P-RIR-BEGINNER`, `evidence: design`. Motivo: arrivare a 2–3 RIR basta (`P-FAILURE-NOT-REQUIRED`, evidenza alta) e chi è all'inizio sta ancora imparando la tecnica. **Non** si cita una stima del RIR peggiore nei principianti: `P-RIR-ACCURACY` dice che la precisione non dipende dall'esperienza.
  - Conflitto `C-RIR-BEGINNER` in `kb/conflicts.yaml` con `P-RIR-HYP` (più vicino al cedimento, più ipertrofia), chiuso dalla decisione di Vincenzo dell'11 novembre.
- **Esercizi meno tecnici**: campo facoltativo `technicalDemand: high` negli esercizi (schema e validatore). Per `under_6_months` gli esercizi `high` si escludono dai candidati disponibili prima della scelta, anche per enfasi ed estensioni; se l'attrezzatura lascia solo quelli, restano tutti. (Prima versione: in fondo all'elenco; non bastava, perché con pochi candidati la scelta `equivalent` li includeva comunque.) Le `alternatives` di Sostituisci non cambiano.
  - **Proposta da confermare con Vincenzo**: `front_squat`, `good_morning`, `sissy_squat`, `single_leg_dumbbell_romanian_deadlift`, `bulgarian_split_squat`, `dip`.
  - Principio nuovo `P-BEGINNER-SIMPLER`, `evidence: design`.

### Versione e compatibilità

- KB `0.25.0` (cambiano i piani generati), voce in `CHANGELOG.md`, `docs/eval-matrice.md` e `kb/README.md` aggiornati.
- Contratto invariato: profilo 1.5, piano 3.0.
- I piani già salvati nell'app non cambiano: si rigenerano solo all'onboarding, a «Ricomincia il mesociclo», a «Cambia piano» e a «Rigenera piano».

## Fase B (app `vscafuto87/barbl`, PR separata dopo il merge del motore)

- **B1**: `dart run tool/update_engine.dart <sha>` (pacchetto della KB, `ENGINE_REF`, ref nel `pubspec.yaml`); aggiornare i test che leggono i contenuti del piano vero (`engine_plan_flow_test`, onboarding, `change_plan_flow_test`, `five_day_plan_calendar_test`…); righe in `docs/decisioni.md` e `docs/architettura.md` (commit del motore). Serve un Flutter SDK nella sessione.
- **B2 (da confermare)**: soglia di riscaldamento per i manubri (`parameters.warmup` oggi ha solo `minLoadKg` = 40 kg, che con i manubri, a carico per mano, non scatta quasi mai). Serve un campo nuovo nel contratto e un valore che oggi non ha fonte. Poi un'indicazione in percentuale per i carichi scritti a mano. Si specifica a parte.

## Criteri di completamento (eval sulla matrice)

1. Nessuna seduta supera `sessionDurationMin` in nessun profilo.
2. Nessuna estensione porta un muscolo oltre `bandMax`.
3. Per ogni profilo, con più tempo le serie totali e il numero di estensioni non diminuiscono. Non si chiede lo stesso per ogni singolo muscolo: gli esercizi del template cambiano con la durata (la chiave della variante la contiene), quindi un muscolo può oscillare di 1,5 serie. Le scelte delle estensioni non dipendono dalla durata.
4. A 60 minuti, massa, palestra completa: spalle ≥ 6 serie frazionarie su 3 e 4 giorni, polpacci ≥ 3 su 3 giorni; Lower A di Upper/Lower ≥ 45 minuti stimati.
5. Profilo `under_6_months`: nessuna settimana di carico con RIR < 2; nessun esercizio `high` dove l'attrezzatura offre un'alternativa.
6. Profili di intermedi e avanzati: mesociclo invariato.
7. Casi d'oro esistenti verdi (aggiornati solo dove cambiano gli esercizi per le estensioni) e casi nuovi: 4 giorni 75 minuti, 3 giorni 90 minuti, principiante 4 giorni 60 minuti.
8. `dart analyze`, `dart test`, `dart run bin/barbl_engine.dart eval --kb ../kb`, `python3 kb/tools/validate.py` senza errori. La CI di GitHub non parte a novembre: verifica in locale, scritta nella PR.

## Risultati dell'implementazione (11 novembre 2026)

- Priorità delle estensioni di enfasi: le estensioni dei distretti in `emphasis` passano per prime, altrimenti con la seduta piena l'enfasi dava meno lavoro al suo distretto di un piano senza enfasi (la proprietà 11 della matrice dell'enfasi falliva).
- `suggestEmphasis` confronta i piani per esercizi e serie: con le estensioni, un'enfasi già coperta da un'estensione uguale cambierebbe solo le etichette. I numeri della KB per le foto non cambiano; i test di `photo_emphasis_test.dart` che dipendevano dal piano di esempio usano ora il piano a 3 giorni da 90 minuti.
- I casi in cui l'enfasi non aggiunge serie ma sposta lavoro tra estensioni (extra 0) sono quelli che con piani pieni prima erano «nessun posto».

## Fuori da questo lavoro

- Stacco da terra e trap bar (obiettivo forza), addome, adduttori e trapezi (cambiano il vocabolario dei muscoli e il contratto): proposte separate.
- Riscaldamento generale e defaticamento: secondo la sintesi dell'11 novembre il primo ha un beneficio piccolo o incerto, il secondo non aiuta il recupero; se ne riparla dopo la fase B.
- Variazione automatica degli esercizi a ogni mesociclo.
