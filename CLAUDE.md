# Hexworks: Cursed Academy - project rules
3D automation / idle game (floating academy island). Godot 4.7.2, Forward+. Spin-off of Downloads\CursedAcademy (untouched).
- Reply in English, short. Never deploy without the user's OK.
- Everything is in `scripts/main.gd` (world, economy, events, boss raids, UI, save). `scripts/m3d.gd` = model library copied from CursedAcademy.
- Loop: 4 wings x 4 stations (Well > Cauldron > Altar > Portal); wing output = slowest station. Masters auto-upgrade. Boss per wing unlocks the next. Runes > relics. Graduate = prestige.
- Test (muted, small): `<godot console exe> --path . --audio-driver Dummy --windowed --resolution 600x600 -- --smoke` must print `SMOKE OK`; SHOTS_DIR env = screenshots. Smoke never touches the save (user://hexworks.json). `--low` = phone quality.
- Not tested yet: real controller (virtual cursor: left stick + A), touch pinch, web export, balance past wing 2.
