# Origine degli schemi del contratto

Copia di `docs/contratto/plan.schema.json` e `docs/contratto/profile.schema.json` dal repository `vscafuto87/barbl`, commit `7d67efa` (merge della pull request #39, 4 novembre 2026). Rispetto alla copia precedente (commit `4268b01`, merge della pull request #37) cambia solo il profilo: `schemaVersion` ammette `1.2` e c'è il campo facoltativo `emphasis` (fino a due distretti tra `glutes_hamstrings`, `shoulders`, `arms`). Lo schema del piano è invariato.

Non si modificano qui. Quando il contratto cambia nell'app, si ricopiano e si aggiorna questo file. Il validatore li usa per controllare che `parameters/` abbia tutti i campi richiesti dal piano e che i valori di `equipment` e `split` esistano.
