# Ghostshift: Haunted Hotel Tycoon ????

A supernatural Roblox tycoon built with Luau and Roblox Studio.

## Core Gameplay
- **Hotel Plot Ownership**: Players claim and renovate a haunted hotel with a reception lobby and guest suites.
- **Guest Simulation**: Autonomous guest arrivals, check-in cycles, room stays, and coin revenue generation.
- **Authoritative Economy**: Server-validated upgrades, currency protection, and tiered visual renovations.
- **Paranormal Events (Phase 2)**:
  - Dynamic supernatural disturbances (flickering teal lights, spectral mist).
  - Multi-clue investigations via ProximityPrompts (Ectoplasmic Residue & Spectral Footprints).
  - Ghost manifestation and timing containment minigame.
  - Ectoplasm currency and rare ghost discoveries (**Jasper the Bellhop**).

## Project Structure
- src/ReplicatedStorage/Configs/: Game balancing (GameConfig.luau, GhostConfig.luau).
- src/ReplicatedStorage/Shared/: Utilities and formatters.
- src/ServerScriptService/: Server orchestrator (ServerMain.server.luau) and core services (EconomyService, HotelService, GuestService, ParanormalService).
- src/StarterPlayerScripts/: Client controllers and HUD management (HUDController.luau, ClientMain.client.luau).

## Developer
- **HighonWheat**
