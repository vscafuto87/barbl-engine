# Origine degli schemi del contratto

Copia di `docs/contratto/plan.schema.json` e `docs/contratto/profile.schema.json` dal repository `vscafuto87/barbl`, commit `42c090d` (merge della pull request #51, 4 novembre 2026). Rispetto alla copia precedente (commit `d15a188`) cambia solo il piano: `alternatives` facoltativo per esercizio (gli esercizi che «Sostituisci» propone, con `initialLoad`). Il profilo è invariato.

Non si modificano qui. Quando il contratto cambia nell'app, si ricopiano e si aggiorna questo file. Il validatore li usa per controllare che `parameters/` abbia tutti i campi richiesti dal piano e che i valori di `equipment` e `split` esistano.
