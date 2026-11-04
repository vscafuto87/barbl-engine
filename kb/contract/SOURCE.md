# Origine degli schemi del contratto

Copia di `docs/contratto/plan.schema.json` e `docs/contratto/profile.schema.json` dal repository `vscafuto87/barbl`, commit `d15a188` (merge della pull request #47, 4 novembre 2026). Rispetto alla copia precedente (commit `7d67efa`) cambia solo il piano: `parameters.move.minRestHours.fullBody` facoltativo (ore minime per una seduta Full body) e la descrizione di `shiftsWeek`. Il profilo è invariato.

Non si modificano qui. Quando il contratto cambia nell'app, si ricopiano e si aggiorna questo file. Il validatore li usa per controllare che `parameters/` abbia tutti i campi richiesti dal piano e che i valori di `equipment` e `split` esistano.
