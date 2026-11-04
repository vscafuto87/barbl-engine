# Template a 5 giorni (massa) e copertura dei 45 minuti — piano

**Obiettivo:** un profilo a **5 giorni** con obiettivo `muscle_gain` o `both` riceve un piano, anche con sedute da **45 minuti**. Il trucco di struttura: cinque sedute da al massimo 15 serie (a 3 minuti per serie = 45 minuti) danno comunque ~70 serie a settimana, quindi il volume per muscolo resta pieno senza una prescrizione «corta» e senza scendere sotto `P-VOL-MIN-10`. I 3 e 4 giorni a 45 minuti restano non coperti (non c'è abbastanza tempo per il volume minimo): è una scelta dichiarata, non un buco. Si colmano anche le lacune di volume trovate dall'eval: spalle, polpacci, glutei.
**Verifica:** CI (`engine`, `validate-kb`). Repo `/home/claude/barbl-engine`, ramo `feature/template-5-giorni` (già creato da `main`); leggere prima il `CLAUDE.md` della radice e i file `kb/templates/*.yaml`, `kb/prescriptions/muscle_gain.yaml`, `docs/eval-matrice.md`. Qui non c'è Dart.

## Vincoli globali
- Regole del `CLAUDE.md`: nessun numero di dominio nel codice Dart; ogni numero in KB cita un principio (se nessuna fonte lo regge, principio `design` con fonte `barbl-design`, provvisorio); testi nostri, it ed en; nessun testo copiato dai libri. I libri sono leggibili (sola lettura) dal tool `mcp__remote-devices__device_bash` (caricare con ToolSearch), cartella montata in `/sessions/rcw-01xoncfca6tjkvgzodjcscxe/mnt/sources/md` (marcatori `<!-- p. N -->`); mai scrivere lì, mai riportare tabelle o nomi commerciali nel repository. Per il controllo dei testi copiati clonare il repo in una cartella temporanea sul dispositivo e lanciare `python3 kb/tools/validate.py --sources-md <md>` (serve un venv con `pyyaml` e `jsonschema` recenti).
- Commit in italiano, mai su `main`, nessuna PR da aprire, nessun merge.

## Task 1 — Esercizi e pattern per le lacune di volume
Dall'eval: spalle 3 serie/settimana, polpacci assenti a 3 giorni e 3 a 4 giorni, glutei <10 in palestra completa, femorali 6 a 3 giorni.
- Aggiungere al vocabolario `kb/vocab/patterns.yaml` (con `region` come gli altri) i pattern necessari e solo quelli: alzate laterali (`lateral_raise`, upper, isolation), deltoide posteriore (`rear_delt_fly`, upper, isolation), estensione d'anca per i glutei (`hip_extension`, lower; es. spinta d'anca / ponte glutei).
- Esercizi nuovi in `kb/exercises/<pattern>/` (schema `kb/schema/exercise.schema.json`; muscoli dal vocabolario `kb/vocab/muscles.yaml`; controllare se i muscoli `side_delts`/`rear_delts`/`glutes` esistono — se non esistono, usare quelli del vocabolario e riportarlo nel report; non allargare il vocabolario dei muscoli senza motivo): almeno un'alzata laterale con manubri (disponibile in tutte le palestre), una versione a cavi, un'alzata per il deltoide posteriore con manubri, e una spinta d'anca/ponte glutei con bilanciere e una con manubri (disponibile in palestra `dumbbells`). Ogni esercizio ha almeno un sostituto esistente o nuovo e `loading.whenLoadUnknown` coerente (`manual` salvo bilanciere da solo).
- Il `equipment` dell'esercizio nel piano deve essere nell'enum `planEquipment` (`kb/vocab/equipment.yaml`).
- Nessun template cambia in questo task. Verifica: `python3 kb/tools/validate.py`.

## Task 2 — Template `ppl_ul_5d`
`kb/templates/ppl_ul_5d.yaml` (+ principio `design` se nessun principio esistente regge la scelta, nella stessa forma di `P-SPLIT-FULL-BODY-3D`): `split: push_pull_legs`, `daysPerWeek: 5`, `goals: [muscle_gain, both]`, schedule lun–ven o lun/mar/gio/ven/sab (decidere in base alle 48 ore di recupero tra sedute dello stesso distretto e documentare), sedute push, pull, legs, upper, lower (`focus` `upper_body`/`legs`).
- Al massimo **15 serie per seduta** (con i valori di `muscle_gain.yaml`: main 4, secondary 3, accessory 3; i superset valgono lo stesso), così una seduta da 45 minuti è ammessa; contare le serie con lo stesso script/metodo del validatore.
- Volume settimanale a serie frazionarie (primario 1, secondario 0,5): petto, schiena, quadricipiti, bicipiti, tricipiti ≥ la soglia di `P-VOL-MIN-10`; spalle laterali/posteriori, femorali, glutei e polpacci almeno al minimo del principio, usando gli esercizi del Task 1. Se il minimo non è raggiungibile in 15 serie a seduta per qualche muscolo, riportarlo nel report con i numeri, non gonfiare le sedute.
- Ogni slot ha candidati per le tre palestre (`full`, `home`, `dumbbells`), il primo candidato ha il pattern dello slot; `askLoad: true` sui principali di spinta, trazione e gamba.
- Non toccare `full_body_3d` né `upper_lower_4d`.
Verifica: `python3 kb/tools/validate.py` (stampa le serie frazionarie).

## Task 3 — Caso d'oro, eval, documenti
- Caso d'oro `kb/golden/04-intermediate-5d-45min-muscle.yaml` + profilo 1.1 (5 giorni, 45 minuti, massa, palestra completa).
- Aggiornare `engine/test/flow/profile_matrix_test.dart` (mappa di copertura: 5 giorni coperti per `muscle_gain`/`both` a tutte le durate, `strength` a 5 giorni ancora non coperto per obiettivo; 3 e 4 giorni a 45 minuti ancora per durata) e controllare che i controlli di volume della matrice passino anche per il 5 giorni; `engine/test/flow/real_kb_test.dart` (il caso «5 giorni non coperto» usato dai test precedenti non vale più: scegliere un altro profilo non coperto, es. 6 giorni non è valido nello schema, quindi usare strength a 5 giorni); `docs/eval-matrice.md` (tabella e conteggi); `kb/README.md` (copertura), `kb/VERSION` `0.6.0` con `engine/test/bundle/bundle_builder_test.dart`.
- Se i conteggi del volume cambiano per i muscoli «noti in deficit» del test, aggiornare l'elenco dei deficit con i riferimenti ai conflitti.
Push, CI `engine` e `validate-kb` verdi; il controllo `--sources-md` sul dispositivo.

## Review Focus
- 5 giorni, palestra `home` e `dumbbells`: piano completo, nessuno slot vuoto.
- 5 giorni a 45 minuti: nessuna seduta stimata oltre 45.
- 3 e 4 giorni a 45 minuti: ancora rifiuto per durata.
- Il piano a 5 giorni valida contro lo schema 3.0 (`split: push_pull_legs` è nell'enum).
