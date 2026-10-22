# GS Ball

Unlock the original GS Ball and Celebi event in **Pokémon Crystal for gen1recomp**.

## Play

1. Import `crystal_gs_ball-1.0.0.zip` through the gen1recomp mod manager and enable **GS Ball** for Crystal.
2. **Defeat the Elite Four and Lance and enter the Hall of Fame.** Then enter **Goldenrod Pokémon Center** and walk toward either exit tile. The original receptionist approaches and gives you the GS Ball.
3. Take it to **Kurt in Azalea Town**. Finish his normal Slowpoke Well introduction first if necessary. Let him examine it until the next in-game day, then return and follow his instructions to the **Ilex Forest shrine** for the native level 30 Celebi encounter.
4. Save normally to keep your progress.

Requires **gen1recomp 0.3.54 or newer** and your imported Crystal game. Works with new and existing saves. Activation requires a recorded Hall of Fame victory; existing postgame saves qualify immediately. Kurt's normal clock and story checks still apply.

## What it changes

The cartridge's delivery gate is the SRAM byte `sGSBallFlag` at bank 1, `$BE3C`, set to `$0B` (`GS_BALL_AVAILABLE`). It is distinct from the event RAM bits recording receipt or completion. Gen1recomp's native equivalent is `save.crystal.gsBall = "have"`, which its `BattleTowerAction GSBALL` handler reads as `$0B`.

This mod activates that exact modeled byte after a recorded Hall of Fame victory. The imported scripts perform the receptionist movement, dialogue, item handoff, Kurt investigation, shrine sequence and battle. It does not grant the item directly, change scene/completion flags, skip Kurt's wait, or inject a Pokémon. Existing nonempty GS Ball states and caught Celebi records are preserved. The native receipt event prevents repeat deliveries.

Activation becomes part of your save when you save normally. Disabling the mod does not undo saved activation. To undo activation, restore a save from before you enabled it. A previously completed event is not restarted. Other mods that deliberately rewrite the quest flags may change its behavior.

## Development

From an engine checkout, with Python and `lupa` available:

```text
python PATH/TO/GSBall/tools/test.py --engine . --cache PATH/TO/crystal
python tools/modkit.py validate PATH/TO/GSBall
python tools/modkit.py lint PATH/TO/GSBall
```

Tests include the production mod loader and the real script VM against an optional local Crystal cache. Cache data and game content are never packaged.

Event reference: [pret/pokecrystal Goldenrod Pokémon Center](https://github.com/pret/pokecrystal/blob/master/maps/GoldenrodPokecenter1F.asm). Credits to pret for the disassembly and the gen1recomp contributors for the native runtime.
