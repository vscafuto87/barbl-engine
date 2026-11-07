# Origine degli schemi del contratto

Copia di `docs/contratto/plan.schema.json` e `docs/contratto/profile.schema.json` dal repository `vscafuto87/barbl`, commit `1d1eddc` (merge della pull request #56, 5 novembre 2026). Rispetto alla copia precedente (commit `42c090d`) cambia solo il profilo: `variantSeed` facoltativo e `schemaVersion` `1.3`. Il piano è invariato.

Dalla KB 0.21.0 lo schema del profilo ha anche `pull_up_bar` e `dip_station` in `gym.equipment`: la stessa modifica entra nell'app con la pull request che aggiorna il pacchetto alla 0.21.0.

Non si modificano qui. Quando il contratto cambia nell'app, si ricopiano e si aggiorna questo file. Il validatore li usa per controllare che `parameters/` abbia tutti i campi richiesti dal piano e che i valori di `equipment` e `split` esistano.

Dalla KB 0.22.0 la copia del profilo è quella del commit `0733c48` dell'app (7 novembre 2026): `schemaVersion` `1.4` e `gym.dumbbellsKg` facoltativo. Il piano è invariato.
