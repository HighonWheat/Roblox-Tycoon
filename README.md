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

### Phase 5: Multi-Floor Expansion, Replayability, Daily Quests & Monetization
- **Second Floor Expansion (Spectral Wing)**:
  - Grand staircase with velvet carpet runner and polished railings leading to Floor 2.
  - Physical locked spectral barrier with floating cost billboard and ProximityPrompt.
  - Server-authoritative unlock validation (250 Coins, Room 1 & 2 Lv 2 prerequisite).
  - Unlocks *Room 3: Spectral Library* (45 base income) and *Room 4: Phantom Ballroom* (70 base income) with visual upgrade tiers.
- **Two Additional Paranormal Disturbances**:
  - *Living Luggage*: A haunted steamer trunk rattles across the lobby with green spark emitters; players investigate brass latches and luggage tags before containing the spirit.
  - *Mirror Visitor*: Frosted vanity mirror manifestations with glowing ectoplasmic handprints and mirror reflections unlocking capture.
- **Guest Variety & Dynamic Satisfaction**:
  - `Regular Specters`: Standard room occupants.
  - `VIP Guests`: Distinct golden sparkle aura, paying 2.0x base coins.
  - `Occultist Guests`: Generates +15 bonus Ectoplasm upon checkout.
  - Dynamic satisfaction rating (80%–175%) scaling payouts based on room tier.
- **Daily Objectives System**:
  - 4 rotating daily objectives: *Hospitality Deluxe*, *Spectral Cleanup*, *Golden Treasury*, *Supernatural Workforce*.
  - 24-hour reset cycle with atomic server reward claiming and duplicate-claim protection.
  - Dedicated `DailyQuestsGui` modal with progress bars and instant claim toasts.
- **Hotel Reputation (Grand Renovation / Prestige)**:
  - Optional prestige system for high-level hoteliers (requires Floor 2 unlocked and Room 1 & 2 at Level 2+).
  - Grants permanent Hotel Reputation Stars (★1 through ★5), awarding +15% permanent income boost per star.
  - Resets room upgrade levels and coins to 100 while strictly preserving discovered ghosts, ghost levels, ectoplasm, and lifetime statistics.
  - Displays reputation star sign over the hotel entrance.
- **Monetization Foundation**:
  - Idempotent `MarketplaceService.ProcessReceipt` handler with dual-layer session cache and persistent purchase tracking.
  - Support for Developer Products (Coin Bundles, 15m Ghost Surge turnover booster).
  - Support for Game Passes (2x Hotel Income multiplier with automatic stacking, VIP Velvet Theme).

---

## 📁 Repository Structure

```
Ghostshift/
├── src/
│   ├── ReplicatedStorage/
│   │   ├── Configs/
│   │   │   ├── GameConfig.luau       # Economy, floors, rooms, quests, prestige, monetization & offline caps
│   │   │   └── GhostConfig.luau      # Ghost rarities, ability formulas & drop rates
│   │   └── Shared/
│   │       └── Formatters.luau       # Currency and duration formatting utilities
│   ├── ServerScriptService/
│   │   ├── ServerMain.server.luau    # Server bootstrap, player lifecycle & Remote wiring
│   │   └── Services/
│   │       ├── DataService.luau      # Persistence, DataStore/Mock, offline calculations & autosave
│   │       ├── EconomyService.luau   # Authoritative balances, upgrades, quests, prestige & state sync
│   │       ├── GuestService.luau     # Guest arrival cycle, VIP/Occultist variety, satisfaction & payouts
│   │       ├── HotelService.luau     # Plot assignment, Floor 2 unlocking, visual room transformations & star signs
│   │       ├── MonetizationService.luau# Idempotent receipt handling, developer products & Game Pass bonuses
│   │       ├── ParanormalService.luau# Multi-event system (Haunted Room, Living Luggage, Mirror Visitor) & minigame
│   │       └── StaffService.luau     # 3D staff models, poltergeist tick loop & staff assignment
│   └── StarterPlayerScripts/
│       ├── ClientMain.client.luau    # Client initialization
│       └── Controllers/
│           └── HUDController.luau    # HUD, Renovations modal, Journal, Welcome Back, Daily Quests & Minigame
└── README.md
```

---

## 👨‍💻 Developer
- **HighonWheat** (yogiankit112@gmail.com)
- Repository: [HighonWheat/Roblox-Tycoon](https://github.com/HighonWheat/Roblox-Tycoon.git)
