# Livello avanzato: template per chi si allena da più di 2 anni

Data: 15 novembre 2026. Richiesta di Vincenzo nel thread «Rendere più dure le sedute per avanzati». Riguarda due repository: `barbl-engine` (KB e motore) e `barbl` (contratto e app).

## Intento

Vincenzo: «vorrei che le sedute fossero un po' più complesse e dure per chi si allena da più di 2 anni»; alla domanda su cosa voglia sentire: «uscire distrutto, quindi cedimento e tecniche di intensità. Definiamo il nuovo livello avanzato per chi si allena da più di 2 anni e creiamo piani di allenamento molto più duri».

Oggi `experience` cambia il piano solo per `under_6_months` (P-RIR-BEGINNER, P-BEGINNER-SIMPLER): `over_2_years` riceve lo stesso piano di `6_months_2_years`. I superset ci sono solo in `upper_lower_4d`. L'app registra già le serie `failure` e `drop` (regole 4 e 5 di `docs/logica-progressione.md`), ma il piano non può prescriverle.

## Obiettivi

- Un livello avanzato vero: piani diversi, più duri, per `experience: over_2_years`, a 3, 4 e 5 giorni, per ogni obiettivo e durata già coperti.
- Cedimento sull'ultima serie degli esercizi dove le fonti lo sostengono, tecniche di intensità (drop set, myo-reps) e superset in ogni seduta.
- Ogni scelta con una fonte nella KB, secondo la gerarchia (tier); i conflitti registrati.
- Varietà invariata: stessi meccanismi di candidati, gruppi intercambiabili e `variantSeed`.
- App allineata: la Seduta mostra e registra le serie prescritte a cedimento, drop set e myo-reps, con il loro «Perché?».

## Non obiettivi

- Piano a 6 giorni: **prossimo sviluppo dopo questo** (Vincenzo, 15/11/2026). Richiede `daysPerWeek: 6` nel profilo, onboarding e «Cambia piano».
- Ripetizioni parziali in allungamento e stretching sotto carico: evidenza contrastante (Wolf et al. 2025, systematic review), fuori.
- Nessun cambiamento ai piani di principianti e intermedi.
- Nessun nuovo passo nell'onboarding: la domanda sull'esperienza c'è già.

## Anti-obiettivi

- Cedimento sui multiarticolari pesanti con bilanciere (squat, stacchi, panca, rematore con bilanciere, military press): rischio tecnico e fatica sproporzionata (Schoenfeld p. 141: il cedimento va usato con più cautela sui multiarticolari). Restano a RIR ≥ 1.
- Cedimento o tecniche nella settimana di scarico.
- Sedute che sforano la durata scelta: la durata resta un vincolo.
- Numeri di dominio nel codice (motore o app): tutto nella KB e nei `parameters` del piano.
- Testo copiato dai libri o nomi di programmi commerciali.

## Approcci considerati

1. **Regole avanzate sopra i template di oggi** (cedimento a scalare, tecniche, superset aggiunti ai piani attuali). Meno lavoro, ma le sedute restano strutturalmente uguali.
2. **Solo RIR più basso** per gli avanzati. Pochissimo lavoro, cambia poco l'esperienza.
3. **Template avanzati separati** — **scelto da Vincenzo il 15/11/2026**. Strutture proprie per l'avanzato (più esercizi, meno serie ciascuno, superset fissi, tecniche dichiarate nello slot), come nei programmi per intermedi e avanzati della KB.

## Fonti (gerarchia della KB)

| Tier | Fonte | Uso |
| --- | --- | --- |
| 1 | ACSM 2026 (pp. 865–866) | Il cedimento non è necessario: resta vero, il livello avanzato è una scelta, non un requisito. Vincola: mai cedimento per tutti. |
| 2 | Refalo 2023 (meta-analisi) | Il cedimento non peggiora l'ipertrofia rispetto a fermarsi vicino. |
| 2 | Robinson 2024 (meta-regressioni) | L'ipertrofia cresce avvicinandosi al cedimento. |
| 2 | Sødal et al. 2023, Sports Med Open 9:66 (meta-analisi, drop set) | Crescita simile alle serie tradizionali in meno tempo. Da aggiungere a `kb/sources/`. |
| 2 | Revisione sui metodi avanzati in soggetti allenati (PMC11022786, da verificare e aggiungere) | Rest-pause e myo-reps alla pari con le serie tradizionali, con meno tempo. |
| 4 | Schoenfeld, Science and Development of Muscle Hypertrophy 2e, pp. 140–141 | Cedimento selettivo, sull'ultima serie, più liberamente sui monoarticolari, soprattutto per chi è esperto; periodizzazione del cedimento. |
| 4 | Helms, Muscle and Strength Pyramid v2, livello 5 (p. 181 e seguenti) | Drop set e rest-pause; superset agonista-antagonista come risparmio di tempo. |
| 4 | Nippard, Muscle Ladder (superset, p. da citare nella KB) | Superset tra muscoli diversi sì, sullo stesso muscolo no. |
| 4 | Nippard, programmi per intermedi e avanzati (Bodybuilding Transformation System p. 27, Pure Bodybuilding 2, Min-Max) | Struttura: ultima serie a cedimento, tecniche sull'ultima serie degli isolamenti, meno serie per esercizio. Solo struttura, nessuna tabella copiata. |

Conflitti da registrare in `kb/conflicts.yaml`:
- **C-RIR-BY-ROLE** (chiuso il 5/11 con «nessun RIR diverso per tipo di esercizio»): si riapre e si chiude di nuovo con la decisione di Vincenzo del 15/11, limitata al livello avanzato. ACSM (tier 1) non è contraddetta: dice «non necessario», non «dannoso».
- **C-ADVANCED-FAILURE** (nuovo): ACSM contro Schoenfeld/Robinson per l'uso sistematico del cedimento; risolto con cedimento solo sull'ultima serie, solo su monoarticolari e complementari, solo dalla settimana 3.

Tutti i principi nuovi sono `provisional` fino alla revisione del coach.

## Design

### KB (`barbl-engine`)

- **Selezione del template**: i template hanno un campo facoltativo `experience` (lista). `select_template` sceglie, tra quelli con i giorni e l'obiettivo del profilo, quello che dichiara l'esperienza del profilo; senza un template dichiarato vale quello senza campo (comportamento di oggi). Nuovi template: `advanced_full_body_3d`, `advanced_upper_lower_4d`, `advanced_ul_ppl_5d`, con `experience: [over_2_years]`.
- **Struttura** (indicativa, da rifinire nella KB con le fonti):
  - 3 giorni: Full body A/B/C con un multiarticolare pesante, un complementare e 2–3 superset di isolamenti.
  - 4 giorni: Upper/Lower × 2, uno dei due giri più pesante (multiarticolari a 5–8) e uno più «pump» (8–15), superset di braccia, spalle e polpacci/addome.
  - 5 giorni: Upper / Lower / Push / Pull / Legs, come `ppl_ul_5d` ma con le regole avanzate.
  - Più esercizi per seduta e **2–3 serie per esercizio** (prescrizioni nuove per ruolo, `prescriptions/advanced_muscle_gain.yaml` e `advanced_strength.yaml`); il volume settimanale per muscolo resta nella fascia (P-VOL-*), cambia la distribuzione.
  - Il finisher degli addominali resta com'è (P-CORE-FINISHER).
- **Tecniche nello slot**: ogni slot del template avanzato può dichiarare `lastSet: failure | drop_set | myo_reps`. Regole:
  - mai su slot `main` né su pattern pesanti con bilanciere (validatore);
  - `drop_set` e `myo_reps` solo su ruolo `accessory` (isolamenti), al massimo `maxTechniquesPerSession` per seduta (valore nella KB, proposta 2);
  - `failure` su `accessory` e `secondary` non con bilanciere.
  Dove i candidati dello slot cambiano attrezzo (seme), la tecnica resta solo se l'esercizio scelto la ammette (campo `allowsFailure` dell'esercizio o regola per attrezzo: scelta del builder, da documentare).
- **Mesociclo avanzato**: gruppo `mesocycle` con una sequenza per esperienza (`weeksByExperience.over_2_years`): RIR 2, 1, 1, 0, scarico 4 (Schoenfeld p. 141; da validare). Il RIR 0 della settimana 4 vale solo per gli esercizi senza divieto; i multiarticolari pesanti hanno il RIR minimo `minRirHeavyCompound` (proposta 1).
- **Quando le tecniche valgono**: parametro `intensityTechniques.fromWeek` (proposta 3): prima di quella settimana l'ultima serie segue il RIR della settimana; nello scarico mai.
- **Parametri nuovi** (gruppo `intensityTechniques`, nel blocco `parameters` del piano): `fromWeek`, `dropSet.loadReductionPct` (proposta 20–25, da fonte), `dropSet.drops` (1), `myoReps.activationReps` (min/max), `myoReps.miniSetReps`, `myoReps.restSeconds` (proposta 15 s, «5 respiri»), `myoReps.maxMiniSets`, `myoReps.stopWhenRepsBelow`. Valori dalla KB con principi e fonti; `provisional: true`.
- **Rationales** nuove, livello `set`, in italiano e inglese: `ADV-FAILURE-LAST-SET`, `ADV-DROP-SET`, `ADV-MYO-REPS`, `ADV-SUPERSET`; livello `mesocycle`: `ADV-MESOCYCLE`.
- **Golden della KB**: profili avanzati a 3, 4, 5 giorni, ogni palestra e durata; proprietà: nessuna tecnica su main o bilanciere pesante, nessuna tecnica in scarico, volume nella fascia, durata rispettata, almeno un superset per seduta, piani diversi con semi diversi.
- `kb/VERSION` minore (0.31.0), CHANGELOG.

### Contratto (`barbl/docs/contratto/`, piano 3.2)

- Esercizio: campo facoltativo `lastSet` (`failure` | `drop_set` | `myo_reps`), scritto solo se presente. Il piano 3.2 è leggibile insieme a 3.0 e 3.1 (`Plan.readableSchemaVersions`).
- `parameters.intensityTechniques` facoltativo (assente nei piani senza tecniche).
- Copia degli schemi nel motore (`kb/contract/`, `SOURCE.md`).

### Motore (`barbl-engine/engine`)

- `select_template` con l'esperienza; prescrizioni avanzate; scrittura di `lastSet`, dei parametri e delle motivazioni; `fit_to_duration` ed `extend_to_duration` trattano i superset come oggi (un superset che resta con un solo slot torna singolo; la tecnica resta sullo slot).
- `schemaVersion` del piano `3.2` solo quando il piano contiene `lastSet`, altrimenti come oggi.

### App (`barbl`)

- **Dominio** (`packages/progression`): nella settimana `≥ fromWeek` (non scarico) l'ultima serie di un esercizio con `lastSet` ha RIR target 0 ed è di tipo `failure`; con `drop_set`, dopo la serie a cedimento compare una riga `drop` con il carico ridotto di `loadReductionPct` (arrotondato con `LoadSteps`, per difetto), senza recupero; con `myo_reps`, la serie di attivazione (a cedimento) e poi mini-serie `myo` allo stesso carico, recupero `myoReps.restSeconds`, fino a `maxMiniSets` o finché le ripetizioni scendono sotto `stopWhenRepsBelow`.
- **Regole di progressione** da aggiungere a `docs/logica-progressione.md` (con l'approvazione di Vincenzo):
  - Regola 1 con una serie prescritta a cedimento: il target di RIR di quella serie è 0, quindi conta solo il massimo delle ripetizioni.
  - Mini-serie myo-reps (`SetKind.myo`, nuovo): come i drop, contano nel volume e non nella regola 1 né nei record. **Da decidere con Vincenzo:** se un blocco myo-reps vale nel volume una serie per mini-serie o una serie in tutto.
  - Recupero di una mini-serie myo-reps: si basa su un orario di fine, come ogni recupero.
- **Seduta (UI)**, con le skill Taste e Impeccable: etichetta sulla riga dell'ultima serie («Cedimento», «Drop set», «Myo-reps») con colore del tipo come oggi (`BarblSetRow`), righe drop e myo con la loro lettera; «Perché?» con la motivazione del piano; riquadro RIR della testata invariato (RIR della settimana); i superset usano `SupersetHeader` e `BarblSupersetItemRow` come oggi. Nessun testo nei widget: ARB in italiano e inglese.
- **Anteprima e Oggi**: nell'anteprima della seduta e in `TodayChanges` una nota breve sulle tecniche dell'esercizio (badge come «Facoltativo»).
- **Passo 7 dell'onboarding**: la frase del mesociclo avanzato (`ADV-MESOCYCLE`) arriva dal piano, nessun testo nuovo nell'app.
- **Aggiornamento del motore** con `tool/update_engine.dart`, piano 3.2 nei test del contratto, flusso `test/app/` con un profilo avanzato: Oggi, Seduta della settimana 4 con cedimento, drop set e myo-reps, Fine, Progressi (volume e record coerenti).
- Chi è già `over_2_years` riceve il piano avanzato solo con «Ricomincia il mesociclo», «Cambia piano» o «Rigenera piano»: il piano salvato non cambia da solo.

## Lasciato al builder

- Esercizi e candidati di ogni slot dei tre template, scelti dai programmi della KB e dal catalogo (153 esercizi).
- Come segnare gli esercizi che ammettono il cedimento (campo dell'esercizio o regola per attrezzo).
- Valori proposti sopra (2, 1, 3, 20–25 %, 15 s) da fondare sulle fonti o dichiarare `design`.
- Ordine delle pull request: KB e motore (una PR), contratto 3.2, dominio dell'app, UI.

## Scelte prese dopo la rilettura (da controllare)

1. **RIR minimo per esercizio**: il motore scrive sull'esercizio il campo facoltativo `rirFloor` (contratto 3.2) per i multiarticolari pesanti; l'app usa `max(RIR della settimana, rirFloor)` per righe, regola 2 e riquadro RIR della testata, che mostra quindi il RIR vero dell'esercizio. La KB decide quali esercizi lo ricevono (`minRirHeavyCompound` e un segno sugli esercizi). L'app non deduce nulla da ruolo o attrezzo.
2. **Obiettivi**: con `muscle_gain` ed `both` valgono cedimento, drop set e myo-reps; con `strength` il template avanzato tiene la struttura (più esercizi, meno serie), i principali seguono le prescrizioni di forza e l'unica tecnica è il cedimento sull'ultima serie degli isolamenti.
3. **Tecniche e superset**: dentro un superset è ammesso solo `failure`; `drop_set` e `myo_reps` solo su blocchi singoli (regola del validatore). La UI dei giri dei superset non cambia.
4. **Durata**: le tecniche restano sugli slot che sopravvivono a `fit_to_duration`; se non ne resta nessuno la seduta corta non ha tecniche. «Almeno un superset per seduta» vale da 60 minuti. Il tempo stimato di un drop set e di un blocco myo-reps è un valore della KB (`timeBudget`), non del codice.
5. **Recupero dei myo-reps**: solo dentro l'app (pillola del recupero), senza Live Activity né notifica, e parte sempre, anche con «Avvia il recupero dopo ogni serie» spento, perché fa parte della tecnica. Sempre da un orario di fine.
6. **Utenti già avanzati**: nessun avviso nuovo. Il piano avanzato arriva al prossimo «Ricomincia il mesociclo» (al più 5 settimane) o con «Cambia piano»; «Rigenera piano» resta com'è (rifiuta un id di piano diverso).

## Decise da Vincenzo

Il 15 novembre 2026 Vincenzo ha approvato la specifica e le due proposte («Ok»).

1. **Volume**: nel piano (volume settimanale del motore, «M serie» del Piano) il drop set vale 0 serie in più; un blocco myo-reps (attivazione e mini-serie) vale 1 serie. Il motore conosce così il volume in anticipo. Nelle serie registrate le mini-serie myo-reps non contano nel volume (conta l'attivazione); i drop registrati seguono la regola 4 come oggi (scelta nostra: la regola 4 confermata non cambia).
2. **Regola 1 con il cedimento**: una serie prescritta a cedimento entra nella regola 1 con RIR target 0, quindi conta solo arrivare al massimo delle ripetizioni. Vale anche per la serie di attivazione di drop set e myo-reps. Drop e mini-serie restano fuori dalla regola 1; le mini-serie myo-reps anche dai record, mentre i drop continuano a contare nei record e nel volume registrato come oggi (regole 4 e 6 invariate, scelta nostra del 15/11: la proposta approvata parlava dei drop solo per la regola 1). Un RIR maggiore di 0 segnato su una serie prevista a cedimento vale come una serie normale, non come un errore. Prima di `fromWeek` tutto resta come oggi.

Da aggiungere a `docs/logica-progressione.md` come regole confermate.

