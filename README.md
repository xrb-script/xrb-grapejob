# xrb-grapejob
esx #esx qbcore #qbox #qbcore #fivem #server

for esx crafting system
https://github.com/byextracode/xc_craft

**Script Overview: Grape Harvesting & Selling System**

*   **Core Functionality:** Allows players to harvest different types of grapes, which can then be (presumably, based on `Config.SellPrices`) processed into wine (crafting not shown in provided code) and sold at designated locations.
*   **Framework Compatibility:** Supports both **ESX** and **QBCore** frameworks, with automatic detection.
*   **Modern Dependencies:** Relies on `ox_lib` (for utilities like progress bars, notifications), `ox_target` (for player interaction with objects/peds), and `ox_inventory` (for item management and weight checks).

**Key Features:**

*   **Configurable Collection Zones:**
    *   Define multiple zones where grape props (e.g., bushes) can spawn.
    *   Props are spawned randomly within a defined area, ensuring they are placed on the ground and don't overlap excessively.
    *   Configurable maximum number of props per zone.
*   **Grape Harvesting:**
    *   Players interact with grape props using `ox_target`.
    *   Collection process includes a configurable animation and an `ox_lib` progress bar.
    *   Multiple types of grapes can be configured as rewards, each with a specific collection chance.
    *   Amount of grapes rewarded per collection is randomized within a defined min/max.
    *   Server-side inventory check (`ox_inventory:CanCarryItem`) before giving items to prevent over-encumbrance.
*   **Prop Management:**
    *   Collected props become visually unavailable and non-interactive.
    *   Props respawn automatically after a configurable delay, appearing in a new random valid location within their zone.
*   **Selling System:**
    *   Define multiple sell locations with static NPC vendors.
    *   Players interact with NPCs (via `ox_target`) to sell items (e.g., wine bottles, as defined in `Config.SellPrices`).
    *   Prices for each sellable item are configurable.
*   **User Interface & Experience:**
    *   Map blips for collection zones and sell locations.
    *   Customizable notifications integrated with `ox_lib`, QBCore's `Notify`, or ESX's `showNotification`.
*   **Highly Configurable:**
    *   Extensive `config.lua` for adjusting zones, prop models, reward items/chances, collection times, animations, sell locations, ped models, prices, and blips.
