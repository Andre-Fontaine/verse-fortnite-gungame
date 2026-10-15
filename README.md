# Gauntlet

A multi-room elimination game mode for Fortnite, built with **Verse** in **Unreal Editor for Fortnite (UEFN)**.

Players queue in a lobby, then fight through a series of rooms. In each room you have to score enough eliminations to qualify for the next one. Anyone who doesn't qualify becomes a spectator. When few players remain, everyone is sent to a Final Showdown where the last person standing wins.

> **Status:** Work in progress. Parts of this project were written with AI assistance and are being reviewed and tested as I learn Verse.

## How the game works

1. **Lobby.** Players wait until the required number have joined (default: 10).
2. **Room 1.** Everyone is teleported in and a 5-second countdown runs. Players are then granted that room's randomly chosen weapon.
3. **Qualifying.** Each room has a kill requirement (default: 5, 3, 2, 1, 1). Reaching it qualifies you, and a share of the other players in the room (about 75% of those remaining) qualify with you and advance.
4. **Elimination.** Players who don't qualify when the room finishes are moved to the spectator area.
5. **Final Showdown.** If fewer than 5 players are left, all remaining players go to the last room and the final fight begins.
6. **Victory and reset.** The winner is announced, then everyone returns to the lobby for the next round.

Players who join while a round is in progress become spectators until the next round.

## Features

- Lobby system with a configurable player requirement
- Up to 5 rooms with per-room kill requirements
- Randomized weapon selection per room from editable pools
- Automatic quota calculation (about 75% of players advance)
- Spectator mode for eliminated and late-joining players
- HUD messages for the lobby, countdowns, kill progress, qualification and victory
- Automatic reset back to the lobby after each match

## Requirements

- Fortnite and UEFN (Unreal Editor for Fortnite)
- Basic familiarity with placing devices in a UEFN level

## Setup

1. Add `gauntlet_manager.verse` to your UEFN project (create a new Verse file in Verse Explorer and paste the code in).
2. Press **Build Verse Code** and fix any errors.
3. Drag the **gauntlet_manager** device from the Content Browser into your level.
4. Place the devices listed below and assign them in the manager's **Details** panel.

### Devices to place and assign

| Property | Device type | Purpose |
|---|---|---|
| `LobbyTeleporter` | Teleporter | Where players wait |
| `LobbyHUD` | HUD Message | Lobby "Waiting for players" text |
| `RoomTeleporters` | Teleporter (one per room, in order) | Entry point for each room |
| `RoomHUDMessages` | HUD Message (one per room, in order) | Countdown, kills and status text |
| `QualificationHUD` | HUD Message | "Qualified!" banner |
| `Room1GranterPool` to `Room5GranterPool` | Item Granter | Weapon options for each room (one is picked at random per match) |
| `WeaponStripper` | Item Remover | Clears weapons between rooms |
| `ElimManager` | Elimination Manager | Elimination handling |
| `SpectatorTeleporter` | Teleporter | Spectator area |
| `SpectatorGranter` | Item Granter | Gives spectators their items |

### Settings you can change

| Property | Default | Meaning |
|---|---|---|
| `LobbyRequiredPlayers` | `10` | Players needed to start a round |
| `RoomKillRequirements` | `{5, 3, 2, 1, 1}` | Kills needed to qualify in each room |

Tip: set `LobbyRequiredPlayers` to `2` while testing with a friend, then set it back before publishing.

## Testing

1. Build Verse code.
2. Click **Launch Session** in UEFN.
3. Add your testers to the project team so they can join.
4. Check the **Output Log** for the `Print` messages to follow what the code is doing.

Things worth testing: joining mid-round, players leaving mid-round, fewer than 5 players (Final Showdown triggers immediately), and running a second full round after the reset.

## Project structure

```
gauntlet_manager.verse   Main game manager device and localized message definitions
```

Main sections of the code:

- **Lifecycle and lobby:** player registration and round start
- **Teleportation:** moving players between lobby, rooms and spectator area
- **Progression and combat:** kills, quotas, qualifying and room transitions
- **UI and countdown:** HUD text and the room countdown
- **Victory and reset:** winner handling and returning to the lobby
- **Helper methods:** safe lookups for kills, rooms and player state

## Known issues and ideas

- Some tracked state (such as `QualifiedRoomSurvivors`) may not be fully used yet.
- `MaxRooms` is not exposed as an editable property.
- Needs more multiplayer testing with full lobbies.

## Learning notes

This project is part of my journey learning Verse. Concepts it uses include classes, `@editable` properties, maps, failable expressions, `spawn` and `Sleep`, events and `Subscribe`, and localized messages.

## License

Add a license of your choice here (for example MIT).