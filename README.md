# Fortnite Verse: Synchronized Gauntlet

A custom game mode architecture built with Verse for Unreal Editor for Fortnite (UEFN).

## Overview
This project is a synchronized multi-room "Gun Game" experience. Players advance through a series of rooms by eliminating opponents. To ensure fairness and prevent spawn-camping, room progression is synchronized: the next round does not begin until all active players have successfully reached the new room.

## Technical Highlights
- **Async Event Monitoring:** Utilizes Verse's asynchronous `spawn` and `.Await()` loops to track player elimination events seamlessly across character respawns and body destructions.
- **Race Condition Mitigation:** Carefully manages inventory stripping and teleports on the same server tick to prevent item duplication and weapon persistence bugs common in UEFN.
- **Dynamic State Synchronization:** Uses custom Maps (`[agent]int`) to track global player state, room occupancy, and localized countdown timers dynamically without hardcoding room limits.
- **Stasis-Free Waiting Phase:** Bypasses Fortnite's rigid Stasis system to allow free movement during waiting periods by actively stripping and granting weapons via array-linked Item Granters.

## File Structure
- `gauntlet_manager.verse`: The core device script managing the game loop, room advancement, and synchronization.

## Setup (UEFN)
1. Place a **Teleporter** and an **Item Granter** for each room.
2. Place a single global **Item Remover** (with *Remove Item* set to *All Weapons*) to handle inventory stripping.
3. Link the devices in sequential order to the `RoomTeleporters` and `RoomItemGranters` arrays on the `gauntlet_manager` device in the editor.
4. Ensure `Pickaxe Damage` is disabled in Island Settings to enforce the unarmed waiting phase.