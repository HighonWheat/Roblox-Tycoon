# Ghostshift: Haunted Hotel Tycoon 👻🏨

A supernatural Roblox tycoon built with Luau and Roblox Studio, engineered with server-authoritative architecture, DataStore persistence, capped offline earnings, and interactive paranormal investigations.

---

## 🎮 Core Gameplay Systems

### Phase 1: Tycoon Foundation & Guest Economy
- **Hotel Plot Ownership**: Players automatically claim a dedicated hotel plot upon joining; plot is gracefully released when leaving.
- **Reception & Guest Suites**: Reception desk and two guest rooms (*Room 1: Whispering Suite*, *Room 2: Phantom Parlor*).
- **Autonomous Guest Simulation**: Guests arrive, walk to reception, check in, occupy rooms, and generate coin payouts upon completing stays.
- **Authoritative Economy**: Server-validated upgrades with 4 distinct visual tiers per room (custom beds, canopy, rugs, floating furniture).

### Phase 2: Paranormal Investigations & Containment
- **Dynamic Haunting Events**: Server-controlled paranormal disturbance with flickering lights, atmospheric spectral mist, and room alerts.
- **Clue Investigations**: Two discoverable clues (*Ectoplasmic Residue* & *Spectral Footprints*) interactable via ProximityPrompts.
- **Manifestation & Containment**: Entity manifests in 3D; player initiates an interactive oscillating needle minigame with sweet-spot timing.
- **Ghost Discovery**: Successful containment awards Ectoplasm currency and rolls for ghost discovery.

### Phase 3: Spectral Staff Roster & Ghost Journal
- **Three Distinct Ghost Types**:
  - **Jasper the Bellhop (Common)**: Grants `Gracious Hospitality` (+15 to +35 coins tip on completed guest stays).
  - **Mildred the Maid (Rare)**: Grants `Ghostly Tidying` (-3.0s to -5.0s faster room turnover).
  - **Grimm the Poltergeist (Epic)**: Grants `Supernatural Conduit` (+8 to +16 Ectoplasm generated periodically).
- **In-World 3D Staff Models**: Assigned ghosts visibly spawn at stations in the hotel with custom accessories (bellhop cap, maid bonnet & duster, poltergeist horns & core orb) and animated overhead BillboardGuis.
- **Ghost Journal UI**: Interactive collection modal showing discovered entities, undiscovered silhouettes, employee assignment, and duplicate leveling up to Lv 5.

### Phase 4: Persistence, Capped Offline Earnings & Release Polish
- **Robust DataStore Persistence (`DataService`)**:
  - Schema versioning (`SchemaVersion = 1`) with automatic migration of legacy profiles.
  - 3-retry exponential backoff with protected calls (`pcall`).
  - Studio MockDataStore fallback enabling seamless local Studio testing without API permission errors.
  - Anti-overwrite safety guards preventing corrupt or failed loads from overwriting valid profiles.
  - Background autosaving every 180 seconds and clean shutdown flushing via `game:BindToClose`.
- **Capped Offline Earnings**:
  - 50% passive rate of hotel income while away.
  - Strict 3-hour (10,800s) maximum cap, with a 60-second minimum absence threshold.
  - Incorporates room upgrades, Bellhop tip bonuses, Housekeeper turnover speed, and Poltergeist offline Ectoplasm generation.
  - **Welcome Back UI (`WelcomeBackGui`)**: Responsive modal displaying formatted time away, accumulated coins/ectoplasm, and atomic, duplicate-proof claim verification.
- **6-Step Onboarding Tutorial**:
  - Progressive guidance covering first stay payout, room renovations, hauntings, containment, and staff assignment.
  - Persistent dismiss button (`✕`) allowing experienced players to hide the banner across sessions.
- **Mobile & Tablet Responsive UI**:
  - Modal mutual exclusion ensuring Renovations, Journal, Welcome Back, and Minigame dialogs never overlap.
  - UISizeConstraints and scaled touch targets for mobile and tablet devices.

---

## 📁 Repository Structure

```
Ghostshift/
├── src/
│   ├── ReplicatedStorage/
│   │   ├── Configs/
│   │   │   ├── GameConfig.luau       # Economy, room upgrades, offline caps & tutorial steps
│   │   │   └── GhostConfig.luau      # Ghost rarities, ability formulas & drop rates
│   │   └── Shared/
│   │       └── Formatters.luau       # Currency and duration formatting utilities
│   ├── ServerScriptService/
│   │   ├── ServerMain.server.luau    # Server bootstrap, player lifecycle & Remote wiring
│   │   └── Services/
│   │       ├── DataService.luau      # Persistence, DataStore/Mock, offline calculations & autosave
│   │       ├── EconomyService.luau   # Authoritative balances, upgrades, staff data & state sync
│   │       ├── GuestService.luau     # Guest arrival cycle, room stay timer & tip rewards
│   │       ├── HotelService.luau     # Plot assignment, visual building & upgrade transformations
│   │       ├── ParanormalService.luau# Haunting events, clue prompts & containment minigame
│   │       └── StaffService.luau     # 3D staff models, poltergeist tick loop & staff assignment
│   └── StarterPlayerScripts/
│       ├── ClientMain.client.luau    # Client initialization
│       └── Controllers/
│           └── HUDController.luau    # HUD, Renovations modal, Journal, Welcome Back & Minigame
└── README.md
```

---

## 👨‍💻 Developer
- **HighonWheat** (HighonWheat@users.noreply.github.com)
- Repository: [HighonWheat/Roblox-Tycoon](https://github.com/HighonWheat/Roblox-Tycoon.git)
