# Changelog

Versioni della knowledge base (`kb/VERSION`, semver). Ogni modifica che cambia un piano generato alza la versione. Il tag di rilascio ha la forma `vX.Y.Z` e coincide con `kb/VERSION`. Si crea con il workflow «Crea tag» (Actions, Run workflow), che controlla `kb/VERSION` e questa pagina; il workflow «Tag di rilascio» lo ricontrolla a tag creato.

## 0.36.0 — 2026-11-27

- Superset con attrezzi vicini (richiesta di Vincenzo del 27/11/2026, che aveva trovato face pull al cavo con donkey calf raise alla macchina): principio nuovo `P-SUPERSET-NEARBY` (scelta di design, provvisorio). Un superset fa risparmiare tempo solo se si passa subito da un esercizio all'altro (`iversen-2021-time-efficient`, fonte nuova, e `zhang-2025-supersets`); nessuno studio confronta attrezzi vicini e lontani, quindi la regola è dichiarata come design.
- `kb/vocab/equipment.yaml`, gruppo nuovo `supersetProximity`: `portableRequires` (`dumbbells`, `bench`: un esercizio che richiede solo queste cose, o niente, si fa accanto a qualunque attrezzo) e `sharedStation` (`cable`, `barbell`, `smith_machine`: due esercizi con lo stesso attrezzo stanno nella stessa stazione; le macchine no). Il validatore controlla i valori.
- Motore: nei blocchi `superset`, dal secondo slot in poi, tra i candidati equivalenti (`equivalent`) si sceglie tra quelli vicini a tutti gli esercizi già scelti del blocco; senza un candidato vicino la scelta resta quella di prima. `KnowledgeBase.nearby`; senza `supersetProximity` nel pacchetto nulla cambia.
- Cambiano i piani con superset: su 2040 superset dei piani in palestra completa (intermedi e avanzati, 3-6 giorni, tre obiettivi, quattro durate, otto semi) le coppie lontane passano da 642 a 64. Restano quelle senza un candidato equivalente vicino (rematore al cavo con military press, curl alla panca Scott con pullover alla macchina o al cavo). Test: `superset_nearby_test.dart` e `flow/superset_nearby_flow_test.dart`.

## 0.35.0 — 2026-11-26

- Errori delle schede tecniche mostrati sul disegno (proposta 6 «Errore comune a confronto» dell'anteprima «Movimenti più chiari», approvata da Vincenzo il 26/11/2026): campo facoltativo `figure` su un errore di `technique.mistakes`, che dice come l'app disegna la figura sbagliata accanto a quella giusta: `half_range` (mezza escursione), `torso_forward` (il busto cade in avanti), `torso_back` (il busto va indietro, con lo slancio), `hips_sag` (il bacino cede), `hips_pike` (il bacino sale). Solo per gli errori che si vedono di lato, su 20 esercizi tra i più usati nei piani (28 errori). Dato di presentazione, non di dominio: nessuna fonte nuova, i testi non cambiano.
- Motore: `KbMistake.figure` (`KbMistakeFigure`), null senza `figure`.
- I piani non cambiano (cambia solo `rulesVersion`).

## 0.34.0 — 2026-11-26

- Frasi delle schede tecniche legate al corpo (proposta 5 «Punti chiave sul corpo» dell'anteprima «Movimenti più chiari», approvata da Vincenzo il 26/11/2026): campo facoltativo `focus` su ogni frase di `technique.cues`, con `part` (`head`, `chest`, `back`, `core`, `shoulder`, `elbow`, `hand`, `hip`, `knee`, `foot`) e `at` (`stretched` con il muscolo allungato, `contracted` con il muscolo accorciato, `whole` per tutta la ripetizione). 338 frasi su 344 lo hanno; le 6 senza sono frasi generali («Inizia con la gamba più debole»). Dato di presentazione, non di dominio: nessuna fonte nuova, i testi non cambiano.
- Motore: `KbTechnique.cueFocus` (`KbCueFocus`, `KbBodyPart`, `KbCueMoment`), una voce per frase, null senza `focus`.
- I piani non cambiano (cambia solo `rulesVersion`).

## 0.33.0 — 2026-11-18

- Piano a 6 giorni per il livello avanzato (richiesta di Vincenzo del 18/11/2026, specifica `docs/superpowers/specs/2026-11-18-piano-6-giorni-avanzati-design.md`): template nuovo `advanced_ppl_6d` (`split: push_pull_legs`, `daysPerWeek: 6`, `experience: [over_2_years]`, tutti gli obiettivi), sedute `push_a`, `pull_a`, `legs_a`, `push_b`, `pull_b`, `legs_b` da lunedì a sabato, domenica di riposo.
  - Giro A pesante: panca, rematore e squat come principali (`askLoad`). Giro B con varianti diverse a 8-12 ripetizioni (`repsOverride`): panca inclinata con manubri o al multipower (nessun candidato in comune con il principale del Push A), trazione dall'alto, pressa o hack squat (squat frontale a casa).
  - Limite del catalogo: con soli manubri e panca l'unico squat disponibile è il goblet squat, che quindi è il principale di entrambe le sedute delle gambe (Gambe A pesante, Gambe B a 8-12 ripetizioni).
  - Ogni muscolo è primario in una sola seduta per giro, quindi mai in due giorni di fila: i deltoidi posteriori stanno nel Push, lo stacco rumeno e lo hip thrust nelle Gambe, l'estensione dei polpacci nel Push A del lunedì (dopo la domenica di riposo, prima del Pull). Finisher degli addominali in Gambe A (mercoledì) e Gambe B (sabato).
  - Tecniche negli slot come negli altri template avanzati: cedimento nei superset di isolamenti, al più due drop set o myo-reps per seduta in blocchi singoli, nessuna tecnica sui principali né sui multiarticolari pesanti. Gli elenchi dei candidati di due slot dello stesso movimento in una seduta (curl, rematori e trazioni) sono disgiunti, così con soli manubri lo stesso esercizio non compare due volte nella seduta.
  - Sedute più corte del 5 giorni: 12-15 serie di base (al più 46 minuti con la massa), il resto del tempo alle estensioni (affondo, leg extension, polpacci, deltoidi posteriori, pullover, abduttori, adduttori, scrollate, avambracci).
  - Volume settimanale misurato con il motore, profilo di riferimento 6 giorni da 60 minuti, massa, palestra completa, senza seme (serie frazionarie): petto 13, dorso 15, spalle 14, tricipiti 11,5, bicipiti 15, quadricipiti 16, femorali 12, glutei 15, polpacci 6 (come gli altri template, eccezione di `C-CALVES-BAND`); fuori dalla fascia per `excludedMuscles` addominali 4, trapezi 4, avambracci 2, adduttori 3,5. Tutti i muscoli grandi stanno nella fascia 10-16 di `belowBand` (P-VOL-MIN-10, P-VOL-BAND-CAP); da 60 minuti in su lo stesso vale per massa ed entrambi in ogni palestra (`advanced_6d_test.dart`). A 45 minuti il taglio per il tempo lascia i glutei a 9,5 (C-TIME-VOLUME).
  - Posti dell'enfasi per il template nuovo in cinque file di `kb/emphasis/`, nelle sedute dello stesso giro di muscoli. I quadricipiti non hanno posti: arrivano già a 15,5-16 serie, al tetto di `belowBand`, e un leg extension in più toglierebbe l'affondo delle estensioni, con meno volume che senza enfasi.
- Principio nuovo `P-SPLIT-PPL-6D` (scelta di design, provvisorio): sei sedute solo per chi è avanzato, struttura presa da due programmi interni a 6 sedute. Fonti nuove, solo per la struttura (`use: internal`, titolo e pagine): `nippard-ppl-6x` (pp. 35-40) e `nippard-powerbuilding-2-6x` (pp. 18-20).
- Contratto del profilo copiato dall'app (commit `0b0d088`): `schemaVersion` `1.6` e `daysPerWeek` `6`. Il motore legge `1.6` e 6 giorni; chi non è avanzato a 6 giorni non è coperto (nessun template a 6 giorni senza `experience`, `NotCoveredReason.goal`).
- Motore: nessun passo assumeva al più 5 sedute; la generazione non cambia. Casi d'oro con due chiavi nuove: `notCovered` (motivo atteso per un profilo non coperto, controllato anche dal validatore) e `noPrimaryMuscleOnConsecutiveDays`. Casi d'oro 15-19 (6 giorni: 60 minuti massa, 45 entrambi, 90 forza, 75 con soli manubri, intermedio non coperto). La matrice passa da 324 a 360 profili e quella dell'enfasi da 756 a 1008 (i 6 giorni solo con `over_2_years`); il test del template a 6 giorni ripete volume, doppioni e giorni consecutivi con due semi.
- I piani a 3, 4 e 5 giorni non cambiano (verificato su 1944 profili, con e senza enfasi; cambia solo `rulesVersion`).

## 0.32.0 — 2026-11-16

- Regola di stallo (scelta di Vincenzo del 15/11/2026, dalla ricerca web): gruppo nuovo `stall` dei `parameters` (`sessions` 2, `dropPct` 10, provvisorio), principio `P-STALL-RESET` (Helms, Pyramid v2 Training, p. 241) e motivazioni `STALL` e `STALL-RETURN`. Due sedute di fila mancate allo stesso carico → la seduta dopo il carico scende del 10% (per difetto sui passi); se va bene si torna subito al carico dello stallo. Il meccanismo è nell'app (regola 19 di `docs/logica-progressione.md`).
- Piano `schemaVersion` `3.3` per tutti i piani, anche quelli avanzati: il gruppo `stall` c'è sempre e la 3.3 contiene i campi della 3.2 (contratto copiato da barbl#132). Sedute ed esercizi non cambiano.

## 0.31.0 — 2026-11-16

- Livello avanzato per chi si allena da più di 2 anni (`experience: over_2_years`, specifica `docs/superpowers/specs/2026-11-15-livello-avanzato-design.md`): template `advanced_full_body_3d`, `advanced_upper_lower_4d` e `advanced_ul_ppl_5d` per tutti gli obiettivi, palestre e durate; prescrizioni `advanced_muscle_gain` e `advanced_strength` (2-3 serie per esercizio, superset a 90 s, un minuto in più per drop set e myo-reps). I 324 profili restano coperti.
- Tecniche dell'ultima serie negli slot (`lastSet`): cedimento sugli isolamenti e sui complementari leggeri, drop set e myo-reps in blocchi singoli, al più 2 per seduta; solo il cedimento con la forza. Parametri nuovi `intensityTechniques` (dalla settimana 3, drop del 25%, myo-reps con attivazione 10-12, mini-serie da 3-4, 5 s di pausa, al più 4, stop sotto 3).
- Mesociclo avanzato: RIR 2, 1, 1, 0 e scarico a 4; i multiarticolari pesanti (`heavyCompound`, segnato su 14 esercizi con bilanciere, affondo compreso) restano a RIR 1 o più e non ricevono tecniche.
- Esercizi rischiosi vicino al cedimento (`noFailure`, nuovo campo dello schema: nordic curl, glute-ham raise, reverse nordic, sissy squat, stacco rumeno a una gamba, split squat bulgaro e al multipower, goblet squat, JM press, Copenhagen): restano nel piano ma senza tecnica. Drop set e myo-reps solo sugli isolamenti (altrove diventano il cedimento); le alternative di «Sostituisci» di un esercizio con una tecnica la ricevono uguale. Negli slot con una tecnica dei template avanzati i candidati sicuri vengono prima e i più rischiosi sono tolti dove c'è un'alternativa.
- Volume dei template avanzati almeno come quello normale per spalle, femorali, glutei e polpacci a 4 giorni da 60 minuti e a 3 giorni da 90 (glutei a 13,5 contro 14 a 3 giorni: conflitto nuovo `C-ADVANCED-VOLUME`, risolto).
- Fonti nuove: Sødal 2023 (drop set), Fonseca 2023 (metodi avanzati in soggetti allenati, PMC11022786), Zhang 2025 (superset), Cowley 2026 (network meta-analisi dei metodi avanzati), Nippard Bodybuilding Transformation System. Principi nuovi `P-ADV-FAILURE-LAST-SET`, `P-ADV-FAILURE-PERIODIZED`, `P-DROP-SET`, `P-MYO-REPS`, `P-SUPERSET-ANTAGONIST`, `P-ADV-STRUCTURE`, `P-TIME-TECHNIQUE`, tutti provvisori.
- Conflitti: `C-RIR-BY-ROLE` riaperto e richiuso il 15/11/2026 per il solo livello avanzato; nuovo `C-ADVANCED-FAILURE` (risolto).
- Motivazioni `ADV-FAILURE-LAST-SET`, `ADV-DROP-SET`, `ADV-MYO-REPS`, `ADV-SUPERSET`, `ADV-MESOCYCLE`; posti dell'enfasi anche nei template avanzati.
- Motivazioni senza i numeri che stanno nei parametri (settimana di inizio, riduzione del drop set, mini-serie dei myo-reps).
- Casi d'oro 09-14 (avanzati) con le chiavi nuove `durationWithinProfile`, `supersetsPerSessionAtLeast`, `techniques` (con `onlySafe`) e `differsWithVariantSeed`; il validatore sceglie template e prescrizione per esperienza e accorcia le sedute come il motore.
- I piani di principianti e intermedi non cambiano (verificato su tutti i 216 profili; cambia solo `rulesVersion`).

## 0.30.1 — 2026-11-15

- Ricerca web sulle evidenze 2022–2026 (report in `/mnt/project-files/ricerca-kb/` del progetto): 12 fonti nuove, dati bibliografici verificati su Crossref. I piani generati non cambiano.
- Principi aggiornati: P-REST-NEUTRAL (Singer 2024: per l'ipertrofia piccolo vantaggio incerto oltre 60 s, nessuna differenza oltre 90 s; i recuperi della KB sono già da 90 s in su), P-PERIODIZATION-NEUTRAL (Moesgaard 2022: piccolo vantaggio per la forza, nessuno per l'ipertrofia), P-DELOAD-REDUCE-VOLUME (Coleman 2024: una settimana di stop non cambia la crescita ma frena un po' la forza delle gambe), P-EXERCISE-VARIATION (Kassiano 2025, curl inclinato e Scott).
- Principi nuovi, a sostegno di scelte già presenti: P-REP-DURATION (nessun tempo prescritto), P-LOAD-RANGE (Lopez 2021, Currier 2023), P-EXERCISE-ORDER (Nunes 2021), P-MODALITY-EQUIVALENCE (Haugen 2023), P-LATERAL-RAISE-EQUIVALENCE (Larsen 2025), P-LEG-EXTENSION-HIP-ANGLE (Larsen 2024/2025, solo per la scheda tecnica).
- Conflitto nuovo `C-MUSCLE-LENGTH-REGIONAL` (aperto) tra P-MUSCLE-LENGTH e la meta-analisi di Varovic 2025; l'ordine dei candidati non cambia.
- Pelland 2026: DOI della versione pubblicata.

## 0.30.0 — 2026-11-14

- Finisher degli addominali da 10 a 20 ripetizioni invece di 10–12 (ruolo `core`, massa e forza; scelta di Vincenzo del 14/11/2026). Molti esercizi del finisher sono a corpo libero e progrediscono solo con le ripetizioni.
- Conflitto nuovo `C-CORE-REPS` (risolto) con il tetto a 12 di P-RIR-ACCURACY, che resta per gli altri ruoli. P-CORE-FINISHER spiega la fascia e cita Schoenfeld (pp. 102 e 105).
- Cambiano solo le ripetizioni del finisher; serie, recuperi, durata ed esercizi restano uguali.

## 0.29.0 — 2026-11-14

- Il finisher degli addominali non conta più nella durata della seduta (scelta di Vincenzo del 14/11/2026). Il campo nuovo del ruolo è `countsTowardDuration`: è falso per `core` e vale vero se manca. Prende il posto di `yieldsToExtensions`, che non c'è più. Le serie del finisher restano fuori da tre conti:
  - `estimatedDurationMin`;
  - il taglio per il tempo, quindi il finisher non si toglie più;
  - lo spazio di enfasi ed estensioni.
- Effetti:
  - ci sono due finisher a settimana a ogni durata, in tutti i 324 profili, sempre ultimi nella loro seduta;
  - a 60 minuti le estensioni tornano quelle della 0.26: a 3 giorni spalle a 6 serie e polpacci a 3, a 4 giorni spalle a 9.
- Estensioni con enfasi: tra i candidati passano per primi quelli che allenano anche un distretto scelto. Così più tempo per le estensioni non dà meno lavoro al distretto chiesto (caso: 5 giorni, forza, 75 minuti, casa, glutei).
- `P-CORE-FINISHER` dice che il finisher, essendo facoltativo, non conta nella durata. Il validatore lo simula.

## 0.28.0 — 2026-11-14

- Catalogo da 140 a 153 esercizi (scelta di Vincenzo del 14/11/2026, «tutti i 13 proposti»), con schede tecniche it/en provvisorie e pagine delle fonti (The Muscle Ladder, The Ultimate Exercise Guide e le note dei programmi di Nippard), scritte con parole nostre.
- Esercizi nuovi: pullover alla macchina (solo come sostituto, come gli altri pullover), leg press a una gamba, leg curl a una gamba, trazioni presa neutra, rematore ai cavi a gomiti larghi, scrollate alla macchina, alzate laterali con appoggio, alzate laterali Egyptian al cavo, tirate al mento ai cavi, JM press, piegamenti presa stretta (pattern `elbow_extension`, a corpo libero), curl alla panca Scott con EZ, reverse curl con EZ (pattern `forearm_isolation`, primario avambracci).
- Template: entrano nei gruppi intercambiabili, allargati di al massimo 2, il leg curl a una gamba (leg curl), il rematore a gomiti larghi (rematori secondari senza `askLoad`), le scrollate alla macchina, le alzate con appoggio ed Egyptian, il curl Scott con EZ e il reverse curl (estensione degli avambracci). In coda, fuori dal gruppo: leg press a una gamba, trazioni presa neutra, tirate al mento, JM press (tecnica alta) e piegamenti presa stretta; negli slot principali o con `askLoad` tutti in coda.
- Sostituti reciproci aggiornati.

## 0.27.0 — 2026-11-14

- Addominali come finisher facoltativo due volte a settimana (scelta di Vincenzo del 14/11/2026). Le due estensioni `trunk_flexion` dei template diventano due slot fissi di ruolo nuovo `core`, in fondo a Lower A e Lower B (4 giorni), Full body A e C (3 giorni), Lower e Gambe (5 giorni).
- Due famiglie diverse nella stessa settimana: slot A flessione dall'alto (crunch ai cavi, alla macchina, con manubrio, decline sit-up, bicycle crunch), slot B dal basso o di stabilità (leg raise alla sbarra e alle parallele, reverse crunch, rollout con bilanciere, Pallof press). Il seme sceglie dentro ogni gruppo; i sostituti attraversano le famiglie.
- Esercizi nuovi (5, da 135 a 140): `reverse_crunch`, `bicycle_crunch`, `decline_sit_up`, `barbell_rollout` (pattern nuovo `trunk_anti_extension`), `cable_pallof_press` (pattern nuovo `trunk_anti_rotation`). Schede tecniche it/en provvisorie.
- Ruolo `core` nelle prescrizioni: 2 serie da 10–12, RIR del mesociclo, 90 s, nessun riscaldamento, `optional: true` e regola `CORE-FINISHER` (motivazione nuova, livello `session`). Campi nuovi del ruolo: `optional`, `rules`, `yieldsToExtensions`.
- Principio `P-CORE-FINISHER` (evidenza bassa, provvisorio) con tre fonti nuove (Vispute 2011, meta-analisi 2022 sulla riduzione localizzata, Contreras e Schoenfeld 2011); conflitto aperto `C-ABS-INDIRECT` con `P-VOL-INDIRECT-SMALL`.
- Motore: piano `schemaVersion` `3.1` con `optional` sull'esercizio (copia del contratto da barbl#126). `fitToDuration` toglie per primo il ruolo `core`; l'enfasi può prendere il posto del finisher; le estensioni usano il tempo che resta dopo di lui (`yieldsToExtensions: false`) e si inseriscono prima del finisher, che resta l'ultimo esercizio.
- Matrice dei 324 profili: a 45 minuti il finisher resta solo in una seduta a 4 e 5 giorni (18 profili su 27 ciascuno) e mai a 3 giorni; a 60 minuti due finisher in 54 profili su 81, uno in 18, nessuno in 9 (3 giorni); a 75 e 90 minuti sempre due. A 3 giorni e 60 minuti le spalle hanno un'estensione in meno (3 serie invece di 6) e i polpacci nessuna.
- Il validatore simula il finisher come il motore (entra solo se la seduta resta nel tempo, l'enfasi lo può togliere).

## 0.26.1 — 2026-11-14

- Revisione delle 135 schede tecniche (richiesta di Vincenzo del 14/11/2026), confrontate con The Muscle Ladder, The Ultimate Exercise Guide e le note dei programmi di Nippard. Restano provvisorie, da rivedere con il coach.
- Correzioni di contenuto: French press con bilanciere con le braccia inclinate verso la testa e il bilanciere dietro la testa (Exercise Guide p. 10); stacco da terra con i dorsali attivi invece dei «gomiti indietro»; rematore con manubrio senza l'immagine del tosaerba, che contraddiceva l'errore sulla rotazione del busto; panca con manubri, piana e inclinata, fino al buon allungamento senza dolore invece di un limite fisso; affondi bulgari, indietro e split squat al multipower: l'errore è il tallone davanti che si stacca, non il ginocchio oltre la punta; pullover con un limite chiaro; leg curl con manubrio, «punte tirate verso le tibie»; scrollate con presa larga e spalle «su e un po' dentro» (Exercise Guide p. 13); leg curl da seduto con il busto in avanti per più allungamento (Exercise Guide p. 20).
- Fonti: hack squat citava le pagine della leg press del Muscle Ladder (ora Exercise Guide p. 17 e i programmi); crunch alla macchina e con manubrio citavano una pagina senza l'esercizio; aggiunte le pagine dei programmi o della guida a 11 schede che citavano solo la pratica di coaching e ad altre 25 schede.
- Nome: «Lat machine alla macchina» diventa «Pulldown alla macchina».
- Refuso «ripartisci» corretto in tre schede. I piani generati non cambiano, salvo `rulesVersion` e il nome italiano del pulldown alla macchina.

## 0.26.0 — 2026-11-13

- Catalogo da 93 a 135 esercizi (decisione di Vincenzo del 13/11/2026: ampliamento importante, solo esercizi di qualità). Ogni esercizio nuovo ha la scheda tecnica it/en (provvisoria, da rivedere con il coach) e cita pagine dei libri di Nippard (The Muscle Ladder e i programmi, testo riformulato).
- Pattern esistenti (27): stacco da terra e stacco sumo, pendulum squat e belt squat, affondi con bilanciere, nordic curl e glute-ham raise, reverse nordic, calf raise a una gamba e donkey calf raise, hip thrust al multipower e alla macchina, rematore T-bar con appoggio, Pendlay e Meadows, pullover con manubrio e pulldown a braccia tese (nuovo pattern `shoulder_extension`, solo come sostituti), panca presa stretta, piegamenti con deficit, floor press con manubri, panca inclinata e lento al multipower, Y-raise ai cavi, curl con EZ, alla panca Scott a macchina e di concentrazione, kickback con manubrio.
- Distretti nuovi (15): muscoli `abs`, `traps`, `forearms`, `adductors` e pattern `trunk_flexion`, `scapular_elevation`, `hip_abduction` (glutei), `hip_adduction`, `forearm_isolation`; crunch ai cavi, alla macchina e con manubrio, leg raise alla sbarra e alle parallele, scrollate con bilanciere, manubri e ai cavi, abduzione e adduzione alla macchina e ai cavi, Copenhagen adduction, flessioni ed estensioni del polso.
- Template: i gruppi intercambiabili degli slot complementari e di isolamento senza `askLoad` crescono di al massimo 2 (regola del 6/11); gli esercizi in posizione accorciata o più impegnativi stanno in coda. Nuove estensioni in coda alle esistenti (priorità più bassa): addome due volte a settimana, abduttori, adduttori, trapezi e avambracci una volta, solo se resta tempo. Il validatore ora segnala con un avviso, invece di un errore, un'estensione senza candidati per una palestra (abduzione e adduzione a casa e con i soli manubri): il motore la salta.
- Nuovo principio `P-VOL-INDIRECT-SMALL` e campo `excludedMuscles` in `parameters/belowBand` (contratto del piano: campo facoltativo, `schemaVersion` invariato): la fascia di volume non vale per addome, trapezi, avambracci e adduttori, quindi la regola 8 dell'app non li segna mai sotto fascia.
- Ogni esercizio nuovo è anche tra i sostituti degli esercizi simili, quindi compare in «Sostituisci».
- Il piano generato cambia per quasi ogni profilo; con la stessa durata, un esercizio di enfasi ora prende spesso il posto di un'estensione dei distretti piccoli invece di aggiungere serie (`suggestEmphasis`, test aggiornati).

## 0.25.1 — 2026-11-13

- Motivazioni `PHOTO-EMPHASIS-SUGGEST` e `PHOTO-EMPHASIS-MORE-VOLUME`: citano anche `P-VOL-DOSE-HYP`, il principio da cui viene la parte «più serie, più crescita» che `P-PHOTO-EMPHASIS` già richiama, così il «Perché?» del suggerimento mostra una fonte pubblica (audit del codice dell'app del 13/11/2026, B6). Le altre motivazioni senza fonte pubblica (`PHOTO-EMPHASIS-NO-*`, `-DATA-DISAGREES`, `EXERCISE-FEEDBACK`) restano scelte di design dichiarate: nessuna fonte inventata.
- `generatePlan` non cambia per nessun profilo (le motivazioni `scope: suggestion` non entrano nei piani e `EXERCISE-FEEDBACK` è invariata), salvo `rulesVersion`.

## 0.25.0 — 2026-11-11

- Estensioni dei template (`P-TIME-EXTEND`): nuovo campo `extensions` nei tre template (slot di seduta, pattern, ruolo e candidati, in ordine di priorità) e nuovo passo del motore dopo l'enfasi. Uno slot entra se la seduta resta nella durata, non ha già il pattern e nessun muscolo supera `bandMax` di `parameters/belowBand`; i distretti di `emphasis` passano per primi. Con 75 e 90 minuti il piano usa il tempo in più (prima era quello da 60) e a 60 minuti spalle, deltoide posteriore, polpacci e glutei raggiungono la fascia dove prima restavano a 0-3 serie. Gli esercizi aggiunti citano la regola `TIME-EXTEND` (nuova motivazione, livello `session`); un piano senza estensioni applicate resta senza.
- Riscaldamento: `warmup` delle prescrizioni accetta `always`, `firstCompoundOfPattern` e `never` (i booleani valgono ancora). Il ruolo complementare ha `firstCompoundOfPattern`: riscaldamento sul primo multiarticolare di ogni pattern della seduta, non solo sull'esercizio principale. Nuovo principio `P-WARMUP-SPECIFIC` (fonte `ribeiro-2021-warmup-review`, solo riassunto letto).
- Principianti (`experience` `under_6_months`): `minRirTargetByExperience` in `parameters/mesocycle.yaml` porta il RIR target delle settimane di carico ad almeno 2 (3, 3, 2, 2, scarico 4); esercizi con `technicalDemand: high` non scelti dal piano se c'è altro (principi `P-RIR-BEGINNER` e `P-BEGINNER-SIMPLER`, conflitto `C-RIR-BEGINNER` chiuso da Vincenzo). Gli altri livelli non cambiano.
- `suggestEmphasis`: i due piani si confrontano per esercizi e serie (non per le etichette `rules`); con le estensioni un'enfasi già coperta da un'estensione uguale vale `PHOTO-EMPHASIS-NO-ROOM`. I numeri di `parameters/photoEmphasis` non cambiano.
- Validatore: controlla estensioni, `technicalDemand` e il nuovo formato di `warmup`; il controllo statico dei casi d'oro conta le estensioni e il RIR minimo. Casi d'oro 06 (4 giorni, 75 minuti), 07 (3 giorni, 90 minuti) e 08 (principiante, 4 giorni, 60 minuti).
- Contratto invariato (piano `3.0`, profilo `1.5`). Il piano generato cambia per quasi ogni profilo di 60 minuti o più; i piani già salvati nell'app non cambiano finché non si rigenera.

## 0.24.0 — 2026-11-10

- Suggerimento di enfasi dalle foto: nuova funzione pura `suggestEmphasis(observations, profile, trainingStats, kb)` (anche `suggestEmphasisFromJson` e il comando `barbl_engine suggest-emphasis`, JSON da `--input` o da stdin a stdout). Dalle osservazioni per distretto di un'analisi delle foto propone al più due distretti per `emphasis` del ciclo successivo, oppure nessuna modifica. Un distretto entra solo se l'osservazione è `less_prominent`, la confidenza è almeno quella della KB, ha un valore di `emphasis`, i dati di allenamento non lo contraddicono (serie fatte non sopra il previsto né sotto la metà, recupero rispettato, dati sufficienti) e la scelta, provata sul piano che il motore genererebbe, non aggiunge più serie settimanali del tetto della KB. A pari confidenza vale l'ordine della KB: nessuna casualità. Ogni scelta porta la motivazione (`PHOTO-EMPHASIS-SUGGEST`) e le condizioni valutate (`evidence`); la mancata modifica ha la sua (`PHOTO-EMPHASIS-NO-EVIDENCE`, `-NO-DATA`, `-DATA-DISAGREES`, `-NO-ROOM`, `-MORE-VOLUME`).
- KB: nuovo principio `P-PHOTO-EMPHASIS` (tipo `design`, provvisorio: una foto è un segnale debole, non decide il volume), nuovo gruppo `parameters/photoEmphasis` con tutti i numeri e gli insiemi (confidenza minima, massimo di distretti, regione → `emphasis`, regioni non enfatizzabili, soglie di volume fatto/previsto, tetto di serie in più; provvisorio) e sei motivazioni it/en. Il gruppo ha `target: engine` (nuovo valore dello schema) e le motivazioni `scope: suggestion` (nuovo campo facoltativo): non entrano mai nel blocco `parameters` né nelle `rationales` di un piano, quindi **`generatePlan` non cambia** per nessun profilo (stesso piano di prima, salvo `rulesVersion`). Il validatore controlla il nuovo gruppo.
- Nota: l'enfasi esistente aggiunge un esercizio in coda alle sedute quando la durata scelta lo permette, quindi può aumentare le serie totali (fino a 6 a settimana nei profili di prova); per questo il tetto sta nella KB (`maxExtraWeeklySets`, 3) e suggestEmphasis lo misura su un piano vero.

## 0.23.0 — 2026-11-08

- Profilo `1.5`: il motore legge `weekdays` (facoltativo, i giorni della settimana in cui l'utente si allena: valori `mon`…`sun` senza doppioni, tanti quanti `daysPerWeek`, altrimenti profilo non valido) e accetta `schemaVersion` `1.5`. Con `weekdays` le sedute del template, nel loro ordine di settimana, vanno ai giorni scelti, in ordine di settimana; senza, vale `defaultSchedule` come prima. Le sedute, gli esercizi e le prescrizioni non cambiano, quindi un profilo senza `weekdays` (o con gli stessi giorni del calendario predefinito) dà lo stesso piano di prima. Il recupero tra due sedute ravvicinate non è controllato dal motore: lo segnala l'app (parametri `move.minRestHours` del piano). Copia dello schema del profilo aggiornata (ramo `claude/adoring-shannon-n9ddhm` dell'app).

## 0.22.0 — 2026-11-07

- Profilo `1.4`: il motore legge `gym.dumbbellsKg` (serie dei manubri, kg di un manubrio, almeno uno e tutti positivi; ordinata e senza doppioni; assente = il motore non la usa) e accetta `schemaVersion` `1.4`. I profili `1.0`–`1.3` si leggono come prima.
- Carichi iniziali dei manubri: la stima da un carico noto con ripetizioni (`source: estimate`) si arrotonda per difetto al manubrio della serie (prima al `stepKg` dell'esercizio; senza `dumbbellsKg` nel profilo resta il `stepKg`, quindi i profili `1.0`–`1.3` danno gli stessi piani); se nessun manubrio della serie basta, vale il carico noto com'è (`source: profile`). Per i manubri la serie fa da passo: `stepKg` del piano resta quello della KB e l'app lo ignora. Copia dello schema del profilo aggiornata (commit `0733c48` dell'app).

## 0.21.0 — 2026-11-06

- Attrezzatura nuova nel profilo: `pull_up_bar` (sbarra per trazioni) e `dip_station` (parallele), nel vocabolario e nella copia dello schema del profilo (stessa `schemaVersion`: si aggiungono solo due valori all'enum). La palestra completa le ha già; a casa e con i soli manubri l'onboarding dell'app le chiede.
- 3 esercizi nuovi a corpo libero (da 90 a 93): trazioni alla sbarra, trazioni presa supina, dip alle parallele (*The Muscle Ladder* pp. 154-155, 158, 187-188). Sono candidati in coda alle trazioni verticali e alle spinte orizzontali, fuori dal gruppo intercambiabile, perché non tutti riescono a farle con il proprio peso fin da subito: escono dove mancano lat machine e macchine (casa con la sbarra) e restano tra le alternative di «Sostituisci» in palestra. Scheda tecnica provvisoria.
- Corretto il test del pacchetto, che nella 0.20.0 si aspettava ancora la versione 0.19.0.

## 0.20.0 — 2026-11-06

- Quarta tornata di catalogo: 28 esercizi nuovi, nessun attrezzo nuovo (da 62 a 90). Dorsali: lat machine a un braccio, presa supina e alla macchina. Femorali e stacchi: leg curl in piedi e con manubrio, good morning, stacco a gambe tese. Quadricipiti: front squat, split squat al multipower, sissy squat. Petto: panca inclinata con bilanciere, chest press inclinata, croci su panca inclinata, croci ai cavi dal basso. Spalle: lento in piedi con manubri, landmine press, alzate laterali su panca inclinata, face pull. Rematori: con bilanciere su panca inclinata, al cavo a un braccio, inverso. Braccia: spider curl, curl al cavo da dietro, french press con manubri, kickback al cavo. Glutei: hip thrust a una gamba, slanci al cavo, iperestensioni a 45 gradi. Ognuno ha muscoli, sostituti e scheda tecnica provvisoria (*The Muscle Ladder*, nuova fonte `nippard-ultimate-exercise-guide` per good morning, front squat e curl al cavo da dietro, `barbl-design` dove non c'è una pagina dedicata). I sostituti degli esercizi esistenti includono i nuovi, quindi «Sostituisci» ne offre di più.
- Template ed enfasi: i nuovi entrano nei candidati dello stesso pattern. Negli slot secondari e di isolamento con `equivalent` ≥ 2 e senza `askLoad` il gruppo intercambiabile si allarga di al massimo due esercizi (`P-EXERCISE-VARIATION`). Gli slot principali, quelli con `askLoad` (carichi chiesti nell'onboarding) e la forza (`P-STRENGTH-SPECIFICITY`) non cambiano. I nuovi in posizione accorciata (kickback, spider curl, slanci, sissy squat) restano in coda, fuori dal gruppo (`P-MUSCLE-LENGTH`). Nel leg curl il gruppo comprende solo flessioni del ginocchio: lo stacco rumeno a una gamba resta come riserva.
- Effetto (300 semi, 60 minuti, massa): esercizi diversi usati da 29 a 42 (3 giorni, palestra completa), da 33 a 44 (4 giorni), da 43 a 62 (5 giorni); a casa da 24-32 a 33-46; con i soli manubri da 18-23 a 23-30. Con i soli manubri e l'enfasi braccia a 4 giorni l'enfasi ora aggiunge entrambi gli esercizi. Nessun numero nuovo.

## 0.19.0 — 2026-11-05

- Schede tecniche: ogni esercizio ha un blocco `technique` (da 3 a 5 passi di setup, da 1 a 3 cue brevi con focus esterno, da 3 a 5 errori comuni con la correzione), in italiano e inglese, scritti con parole nostre. Fonte principale *The Muscle Ladder* di Nippard (pp. 110-242, nuova fonte `nippard-muscle-ladder`); gli errori comuni senza pagina citano `barbl-design`. Tutte le schede sono provvisorie, da rivedere con il coach. Il validatore richiede la scheda per ogni esercizio; il motore la legge (`KbExercise.technique`) e la mette nel pacchetto. I piani generati non cambiano.

## 0.18.0 — 2026-11-05

- Tre enfasi nuove nel profilo (`emphasis`): `quadriceps`, `chest`, `back`, accanto a `glutes_hamstrings`, `shoulders` e `arms`; sempre al massimo due, stesse regole di durata. Posti: quadricipiti con la leg extension (Full A e Full C, Lower B, Gambe e Lower; senza macchine un affondo o uno squat con manubrio), petto con le croci (Full A e Full C, Upper A, Push e Upper), schiena con una trazione verticale o un rematore (Full A e Full C, Upper A e Upper B, Pull e Upper).
- L'enfasi non ripete più un esercizio già presente nella seduta: prende il primo candidato disponibile che la seduta non ha, e se non ce n'è nessuno salta il posto. Corregge il limite noto della 0.7.0 (con i soli manubri l'esercizio aggiunto ripeteva quello della seduta); a 4 e 5 giorni con i soli manubri l'enfasi schiena non trova esercizi nuovi e non aggiunge nulla. Ai curl dell'enfasi braccia si aggiungono il curl a martello e quello su panca inclinata come riserve.
- Principio `P-SEX-RESPONSE` (Roberts 2020, Refalo 2025, solo abstract; Schoenfeld p. 173): a parità di programma la crescita relativa è simile tra i sessi, quindi stesse regole per tutti e nessuna domanda sul sesso; le differenze di obiettivo passano dall'enfasi. Conflitto aperto `C-SEX-FATIGUE` (Nuckols 2026: le donne recuperano di più tra le serie, non tra le sedute), da rivedere con il coach.
- Matrice dell'enfasi da 432 a 756 profili (sette varianti). Nessun numero nuovo.

## 0.17.0 — 2026-11-05

- Terza tornata (manubri e casa), con letture degli studi: 3 esercizi nuovi (curl alla panca Scott con manubrio, stacco rumeno a una gamba con manubrio, Arnold press). Estesi `P-MUSCLE-LENGTH` (Maeo 2021: leg curl da seduto più dei ischiocrurali che da prono; Pedrosa 2023: curl nel tratto allungato) e nuovo `P-PUSH-UP-LOW-LOAD` (Kikuchi 2017). Di conseguenza il leg curl da seduto precede quello da prono (che passa in coda, dopo lo stacco rumeno a una gamba) e i curl allungati (panca inclinata, Scott) entrano per primi nei candidati dei bicipiti (`equivalent` 4); l'Arnold press è intercambiabile con la panca da seduto nelle spalle. Lo stacco rumeno a una gamba e l'Arnold press non hanno uno studio diretto: valgono per la varietà (`P-EXERCISE-VARIATION`). Principi provvisori, nessun numero nuovo, nessuno split nuovo.

## 0.16.0 — 2026-11-05

- Chiusi i cinque conflitti aperti (decisioni di Vincenzo): C-RIR-BY-ROLE, C-REST-STRENGTH, C-STRENGTH-VOLUME e C-TIME-VOLUME senza cambi al motore (scelte di design accettate); C-CALVES-BAND con un secondo esercizio per i polpacci in Lower B del template a 4 giorni (6 serie a settimana, come a 5 giorni) e l'eccezione dichiarata sotto le 10 serie. I piani a 4 giorni cambiano (uno slot in più, tolto per primo nelle sedute corte). Nessun numero nuovo.

## 0.15.0 — 2026-11-05

- Seconda tornata di catalogo, con letture degli studi: 8 esercizi nuovi (calf raise alla leg press e al multipower, estensioni sopra la testa con bilanciere, ponte per i glutei, pull-through ai cavi, affondi indietro, step-up, alzate posteriori su panca inclinata). Principio `P-MUSCLE-LENGTH` (Maeo 2023: tricipiti più cresciuti con le estensioni sopra la testa che con i pushdown; Kinoshita 2023, testo completo: gastrocnemi più cresciuti con il calf raise in piedi che da seduto; revisione di Pedrosa 2026): i candidati che allungano il muscolo vanno per primi e il pushdown e il calf seduto restano in coda, fuori dal gruppo intercambiabile. **Correzione della 0.14.0**, che aveva messo il calf seduto tra i candidati intercambiabili. Principio `P-GLUTE-EXERCISE-EQUIVALENCE` (Plotkin 2023: hip thrust e squat danno una crescita dei glutei simile): hip thrust, ponte, pull-through e affondi sono candidati intercambiabili. Tutti i principi sono provvisori. Nessun numero nuovo, nessuno split nuovo.

## 0.14.0 — 2026-11-05

- Più varietà dal catalogo: 10 esercizi nuovi (curl a martello, curl su panca inclinata, alzate laterali alla macchina, pec deck inverso, pec deck, calf seduto, leg curl da seduto, rematore alla macchina, lat machine presa neutra, hack squat) inseriti nei candidati intercambiabili dei template (`equivalent` 2 o 3, sempre dentro l'attrezzatura del profilo). Ricerca sugli split (meta-analisi di Schoenfeld 2016 e 2019, Ramos-Campo 2024; letti solo i riassunti): a volume e frequenza pari lo split cambia poco per l'ipertrofia, e a 3 giorni la struttura che dà 10 serie a muscolo con due stimoli è comunque il Full body; per questo non aggiungo template nuovi e la varietà viene dal catalogo e dal seme. Nessun numero nuovo.

## 0.13.0 — 2026-11-05

- Copertura di tutta la matrice di 324 profili (prima 216): una seduta che non sta nella durata del profilo si accorcia (`P-TIME-TRIM`: si tolgono prima gli isolamenti, poi i complementari, mai i principali) invece di rifiutare il profilo, e `ppl_ul_5d` vale anche per la forza (prescrizione strength, stessa decisione di C-STRENGTH-VOLUME). Conflitto aperto `C-TIME-VOLUME`: con poco tempo il volume di alcuni muscoli scende sotto la soglia. Nessun numero nuovo.

## 0.12.0 — 2026-11-05

- Tantissimi piani per lo stesso profilo: `variantSeed` facoltativo nel profilo 1.3 (app barbl#56) mescolato nella scelta; senza seme il piano resta deterministico. `equivalent: 2` anche sugli esercizi secondari dei template per massa ed entrambi (spinte, trazioni orizzontali, stacchi, affondi, hip thrust, spalle); per la forza principali e secondari restano fissi (principio di design `P-STRENGTH-SPECIFICITY`). La chiave di scelta non include più obiettivo ed enfasi. L'hash ha un finalizzatore (i bit bassi di FNV-1a erano quasi solo parità). Caso d'oro 02 senza il carico del rematore con manubrio. Nessun numero nuovo.

## 0.11.0 — 2026-11-05

- Piani vari: gli slot di isolamento (braccia, spalle laterali e posteriori, polpacci, petto) dichiarano `equivalent: 2` e il motore assegna uno dei due primi esercizi disponibili con un hash deterministico di profilo (senza carichi noti), seduta e posizione. Stesso profilo, stesso piano; profili diversi possono avere esercizi diversi. Principio `P-EXERCISE-VARIATION` (tier 3, provvisorio), conflitto differito `C-LOAD-RATIO-EXERCISES` (nessun rapporto di carico con fonte). Nessun numero nuovo.

## 0.10.0 — 2026-11-04

- Alternative per «Sostituisci»: ogni esercizio del piano porta `alternatives` (contratto: campo facoltativo, app barbl#51), cioè i suoi sostituti della KB nell'ordine dichiarato, solo se eseguibili con l'attrezzatura del profilo e non già nella stessa seduta. Il carico delle alternative è `manual` (nessun rapporto tra esercizi ha ancora una fonte). Nessun numero nuovo.

## 0.9.0 — 2026-11-04

- Sposta seduta: `parameters.move.minRestHours.fullBody` = 48 ore per le sedute Full body (contratto: campo facoltativo, app barbl#47); `shiftsWeek` resta falso. I piani Full body cambiano solo in questo parametro.

## 0.8.0 — 2026-11-04

- Conversione dei carichi noti: un `knownLoads` con `reps` si converte in carico di lavoro (Epley, poi carico alle ripetizioni e al RIR della prima settimana, arrotondato al passo inferiore) con `source: estimate`; senza `reps` il carico vale com'è. Parametri in `parameters/trialLoad` (`knownLoadConversion`: divisore di Epley e RIR assunto 0), principio di design `P-KNOWN-LOAD-RIR`. Il caso d'oro 01 cambia (80 × 8 → 77,5 kg).

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
