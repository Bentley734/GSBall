# GS Ball

Play the GS Ball and Celebi quest in **Pokémon Gold, Silver and Crystal for gen1recomp**, after defeating the Elite Four and Lance.

## Play

1. Import `crystal_gs_ball-1.1.0.zip` through the gen1recomp mod manager and enable **GS Ball** for your game. Existing installations can update from the same repository.
2. **Defeat the Elite Four and Lance and enter the Hall of Fame.** Then enter **Goldenrod Pokémon Center** and walk toward either exit tile. The original receptionist approaches and gives you the GS Ball.
3. Take it to **Kurt in Azalea Town**. Finish his normal Slowpoke Well introduction and collect any outstanding apricorn balls first. Let him examine it until the next in-game day, then return and follow his instructions to the **Ilex Forest shrine** for a native level 30 Celebi encounter.
4. Save normally to keep your progress.

Requires **gen1recomp 0.3.54 or newer** and your imported game. Works with new and existing saves. Activation requires a recorded Hall of Fame victory; existing postgame saves qualify immediately. Kurt's normal clock and story checks still apply.

## Crystal: original event activation

The cartridge's delivery gate is the SRAM byte `sGSBallFlag` at bank 1, `$BE3C`, set to `$0B` (`GS_BALL_AVAILABLE`). It is distinct from the event RAM bits recording receipt or completion. Gen1recomp's native equivalent is `save.crystal.gsBall = "have"`, which its `BattleTowerAction GSBALL` handler reads as `$0B`.

This mod activates that exact modeled byte after a recorded Hall of Fame victory. The imported scripts perform the receptionist movement, dialogue, item handoff, Kurt investigation, shrine sequence and battle. It does not grant the item directly, change scene/completion flags, skip Kurt's wait, or inject a Pokémon. Existing nonempty GS Ball states and caught Celebi records are preserved. The native receipt event prevents repeat deliveries.

Activation becomes part of your save when you save normally. Disabling the mod does not undo saved activation. To undo activation, restore a save from before you enabled it. A previously completed event is not restarted. Other mods that deliberately rewrite the quest flags may change its behavior.

## Gold and Silver: quest adaptation

Gold and Silver do not contain Crystal's GS Ball delivery or Celebi event scripts. Version 1.1.0 adds an adaptation using their own receptionist sprite, maps, Kurt, shrine, native inventory, next-day reset and wild battle system. Crystal continues using its original scripts.

The receptionist approaches when you reach either Goldenrod Pokémon Center exit after becoming Champion. Kurt studies the ball until his native daily reset, then returns it and directs you to the shrine. At the shrine, choose YES to place the ball and encounter Celebi. Capturing Celebi completes the quest. In Gold/Silver, a fainted or escaped Celebi can be challenged again by examining the shrine; whiteout also preserves that opportunity. Declining the shrine prompt keeps the ball.

The adaptation uses new dialogue and does not reproduce Crystal's special outdoor Kurt scene or Celebi arrival animation. It uses the unused item slot `$73` (`ITEM_73`, normally TERU-SAMA) as a protected GS Ball key item. The mod does not require a Crystal ROM/cache to play Gold or Silver and distributes no game assets.

Quest progress is stored with each gen1recomp save under `modData.crystal_gs_ball.gsPort`. Keep the mod enabled to continue the Gold/Silver quest; the added quest is not part of a vanilla cartridge save export. Existing Crystal progress and all native apricorn flags are preserved.

## Development

From an engine checkout, with Python and `lupa` available:

```text
python PATH/TO/GSBall/tools/test.py --engine . --cache PATH/TO/crystal
python tools/modkit.py validate PATH/TO/GSBall
python tools/modkit.py lint PATH/TO/GSBall
```

Tests include the production mod loader and the real script VM against optional local Gold, Silver and Crystal caches. Pass the Crystal cache folder; the other two are read from adjacent `gold` and `silver` folders. Cache data and game content are never packaged.

Version 1.1.0 passes 120 Crystal assertions and 260 Gold/Silver assertions on each of engine versions 0.3.54 and 0.3.58, plus strict modkit validation and content lint. These are headless integration tests; a full graphical playthrough remains unverified.

Event reference: [pret/pokecrystal Goldenrod Pokémon Center](https://github.com/pret/pokecrystal/blob/master/maps/GoldenrodPokecenter1F.asm). Gold/Silver reference: [pret/pokegold Ilex Forest](https://github.com/pret/pokegold/blob/master/maps/IlexForest.asm). Credits to pret for the disassemblies and the gen1recomp contributors for the native runtime.
