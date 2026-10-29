# SurvivorUI Classic

The game's own interface for Azeroth Survivors, with a few things more:

- **Everything movable.** Click the gear on the minimap, then **Move frames**. Every piece gets a green box: drag a box to move its piece, right-click it to put the piece back. This covers the minimap, the player and target frames, the party, the action bar with its experience bar, the buffs, the chat and the addon's own pieces.
- **Health in numbers.** The target frame shows an enemy's real health, `12.3k / 40.0k (31%)`, read from the game. Each frame can show Off, Value, Percent or Both.
- **Run frame.** It sits at the top of the screen and shows:
  - the zone, with its Heroic level or Endless;
  - the time against the final boss's second;
  - a bar with a skull for every boss: grey to come, white next, orange alive, green slain;
  - what comes next.
- **Boss bars.** One thin bar for each boss alive.
- **Build list.** Your six spell slots, filled or empty, with each spell's rank and cooldown, and your racial apart.
- **Jewelry.** The neck, rings and trinkets you wear this run, and what each one gives.

The run frame, build list and jewelry can stay over the game's level-up and jewelry cards, so you see them while you choose. Every piece can be turned on or off from the minimap menu.

## Survivor UI and SurvivorUI Classic

They change the same frames, so only one of them runs. If both are installed, a panel asks which one you want. To switch later, use the minimap menu or `/suic`, then close the game and open it again. Survivor UI 3.0.44 or newer steps aside by itself when SurvivorUI Classic is chosen.

## Commands

- `/suic`: help, or the choice panel while Survivor UI is in use.
- `/suic move`: move frames.
- `/suic reset`: every frame back in its first place.

## Changes

### 0.1.0 (unreleased)
- First version: the choice panel with Survivor UI, Move frames, health text on the player and target frames, the run frame, boss bars, the build list and the jewelry worn.

## License

GPL-3.0. Some of the logic comes from [Survivor UI](https://github.com/morderous/survivor-ui), by the same author.
