<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

---

# 🎯 RSG‑Inventory  
**Converted from qb‑inventory fully optimized for RedM Roleplay with RSG Core & ox_lib.**

![Version](https://img.shields.io/badge/version-2.6.3-red)
![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-MIT-green)

> A robust, modular inventory system for your RedM server.

---

## 🛠️ Dependencies
Make sure these resources are running before starting **rsg-inventory**:

- [**ox_lib**](https://github.com/Rexshack-RedM/ox_lib) ⚙️  
- [**ox_target**](https://github.com/Rexshack-RedM/ox_target) 👁️  
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠  
- [**rsg-weapons**](https://github.com/Rexshack-RedM/rsg-weapons) 🔫

---

## ✨ Features
- 🗄 **Stashes** — Personal and/or shared  
- 🐎 **Vehicle Trunk & Glovebox** — Includes optional horse saddlebag support  
- 🏪 **Shops** — Works great with [**rsg-shops**](https://github.com/Rexshack-RedM/rsg-shops) 🥐  
- 🎒 **Item Drops** — Physical objects in the world  
- 🔁 **Player Trading** — Right-click a player to send a trade request; secure item exchange with escrow system and full rollback on cancel/disconnect  
- ⚖ **Configurable Limits** — Stash, and drop sizes  
- 🚫 **Hotbar Spam Protection** — Adjustable timers and notifications  

---

## 📸 Inventory Preview
<p align="center">
  <img width="503" height="638" alt="Inventory Preview" src="https://github.com/user-attachments/assets/f1d965e0-19cb-4131-af79-bc374b2c9913" />
</p>

---

## 📜 Example Config
```lua
return {
    StashSize = { maxweight = 2000000, slots = 100 },
    DropSize = { maxweight = 1000000, slots = 50 },
    HotbarSpamProtectionTimeout = 500,
    HotbarSpamProtectionNotify = false,
    GiveItemType = "nearby",
}
```

---

## 📂 Installation
1. **Download** this resource and place it in your `resources` folder  
2. **Install** and start `ox_lib` and `rsg-core` and  `rsg-shops` 
3. Add `ensure rsg-inventory` to your `server.cfg`  
4. Edit `shared/config.lua` to fit your server’s needs

```lua
--- NOTES

--- player inventory max weight and slots are configured in rsg-core\config.lua (RSGConfig.Player.PlayerDefaults)
--- if inventory items should decay at modified rate, add decay{PERCENTAGE} to stash name (i.e.: basement69-decay30, freezer111_decay0, composter333decay5000)
```
---

## 💎 Credits
- [**The Icon Library Project**](https://github.com/TankieTwitch/FREE-RedM-Image-Library) 🖼 — free RedM item icons

---
