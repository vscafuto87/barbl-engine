# barbl-engine

Motore dei piani di allenamento di Barbl: legge la knowledge base come dati e produce piani conformi al contratto dell'app (`vscafuto87/barbl`, `docs/contratto/`).

Il repository ha due pezzi:

- `kb/` — la knowledge base (YAML con schema), ex `barbl-kb`, con la sua storia. Ogni numero di dominio sta qui.
- `engine/` — il pacchetto Dart `barbl_engine`: legge il pacchetto generato dalla KB e produce il piano. Non contiene numeri di dominio.

La specifica è in `docs/superpowers/specs/`, il piano di lavoro in `docs/superpowers/plans/`. Le regole di lavoro sono in `CLAUDE.md`.

## Comandi

```bash
pip install -r kb/requirements.txt
python3 kb/tools/validate.py          # validazione della KB
cd engine && dart test                # test del motore
```
