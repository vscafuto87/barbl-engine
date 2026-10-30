# barbl-engine

Motore dei piani di allenamento di Barbl e la sua knowledge base. `kb/` contiene i file YAML letti come dati (ex `barbl-kb`, storia conservata); `engine/` è il pacchetto Dart `barbl_engine` che li legge e produce i piani del contratto dell'app (`vscafuto87/barbl`, `docs/contratto/`). Il motore non contiene numeri di dominio: stanno tutti nella KB.

## Struttura

- `kb/VERSION` — `rulesVersion` della KB (semver). Ogni modifica che cambia un piano generato alza la versione.
- `kb/schema/` — JSON Schema di ogni tipo di file. La CI li applica.
- `kb/contract/` — copia degli schemi del contratto dell'app (`plan.schema.json`, `profile.schema.json`), con il commit di origine in `kb/contract/SOURCE.md`. Non si modificano qui: si aggiornano dall'app.
- `kb/vocab/` — vocabolari chiusi: muscoli, pattern di movimento, attrezzatura.
- `kb/sources/` — una fonte per file.
- `kb/principles/` — un principio per file, in sottocartelle per tema.
- `kb/exercises/` — un esercizio per file, in sottocartelle per pattern.
- `kb/templates/` — split e sedute fatte di slot.
- `kb/prescriptions/` — serie, ripetizioni e recupero per obiettivo e ruolo.
- `kb/parameters/` — un file per gruppo del blocco `parameters` del contratto, più il mesociclo.
- `kb/rationales/` — testi del «Perché?» in italiano e inglese, uno per `ruleId`.
- `kb/conflicts.yaml` — conflitti tra fonti e decisioni prese.
- `kb/golden/` — profili sintetici e proprietà attese, per le eval del motore.
- `kb/tools/` — validatore (`python3 kb/tools/validate.py`) e strumenti di estrazione.
- `engine/` — pacchetto Dart (`lib/src/kb/`, `generate/`, `contract/`, `bundle/`, riga di comando in `bin/`).
- `docs/superpowers/{specs,plans}/` — specifica e piano di lavoro.

## Regole sulla KB che non si discutono

- **Mai il testo delle fonti.** Le fonti con `use: internal` (libri e programmi acquistati) entrano solo come riferimento: titolo, pagina, file locale. Ogni frase della KB è scritta con parole nostre. Il validatore, con `--sources-md`, cerca sequenze di 8 parole copiate dai Markdown estratti.
- **I PDF, i Markdown estratti e i dati strutturati dei programmi non entrano mai nel repository.** Restano in `~/Progetti/app-palestra/sources/` sul Mac.
- **Ogni numero ha un'origine.** Un valore di `kb/parameters/` o `kb/prescriptions/` cita i principi da cui viene; se nessuna fonte lo sostiene è un principio di tipo `design`, dichiarato come tale.
- **Gerarchia delle fonti** per risolvere i conflitti (`tier`): 1 position stand e umbrella review, 2 meta-analisi e meta-regressioni, 3 RCT, 4 libri e programmi di autori evidence-based, 5 pratica dei coach e scelte di design. Un conflitto si registra in `kb/conflicts.yaml`, non si nasconde.
- **Provvisorio finché non confermato.** Un principio è `confirmed` solo con almeno una fonte primaria letta nel testo completo (`access: full_text`) e la revisione di un coach (`reviewedBy`). Un gruppo di parametri ha `provisional: false` solo se tutti i suoi principi sono confermati. Un principio con un conflitto `open` non alimenta un parametro confermato.
- **Programmi famosi come termine di confronto, non come regole.** Entrano nelle eval e nella struttura dei template (pattern, ruoli, sostituzioni), mai con nomi commerciali, note o tabelle copiate.
- **Identificativi in inglese**, uguali a quelli del contratto (`exerciseId`, `ruleId`, valori di `equipment` e `split`). Testi per l'utente in italiano e inglese.
- **Nessun consiglio medico** nei testi.
- Se un dato non ha una fonte, non inventarlo: segnalo come scelta di design o chiedi.

## Regole sul motore che non si discutono

- **Nessun numero di dominio nel codice Dart**: serie, ripetizioni, recuperi, RIR, soglie e tempi vengono solo dalla KB. Le costanti ammesse sono quelle di formato (`bundleFormat = 1`, `schemaVersion` del contratto `"2.0"`, `"1.0"` del profilo).
- **`generatePlan` è pura e deterministica**: niente orologio, casualità o I/O; non lancia per un profilo.
- **`lib/` fuori da `lib/src/bundle/` non importa `package:yaml`, `dart:io` né `package:json_schema`** (lo verifica `engine/test/architecture/imports_test.dart`).

## Comandi

- Validazione della KB: `python3 kb/tools/validate.py` (richiede `pyyaml` e `jsonschema`: `pip install -r kb/requirements.txt`)
- Controllo dei testi copiati: `python3 kb/tools/validate.py --sources-md ~/Progetti/app-palestra/sources/md`
- Test del motore: `cd engine && dart test`

## Modo di lavorare

- **Mai commit diretti su `main`.** Ogni lavoro va su un ramo (`feature/…`, `kb/…`, `fix/…`, `docs/…`) e arriva su `main` con una pull request approvata da Vincenzo. Non fare il merge da solo.
- Prima di dichiarare finito: CI verde (`validate-kb` ed `engine`) e, per la KB, `python3 kb/tools/validate.py` senza errori.
- Una pull request per tema (una ricerca, un gruppo di esercizi, un template, una parte del motore).
- Commit e testi in italiano.
