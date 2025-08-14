# ![RSG Logo](assets/rsg-logo.jpeg)  
# 🎯 RSG‑Inventory  
**Converted from qb‑inventory — fully optimized for RedM Roleplay with RSG Core & ox_lib.**

![Version](https://img.shields.io/badge/version-1.0.0-red)  
![Platform](https://img.shields.io/badge/platform-RedM-darkred)  
![License](https://img.shields.io/badge/license-MIT-green)

> A robust, modular inventory system for your RedM server, featuring stashes, shops, weapon attachments, and more.

---

## 🛠️ Dependencies
Make sure these resources are running before starting **rsg-inventory**:
- [**ox_lib**](https://github.com/overextended/ox_lib) ⚙️
- [**rsg-core**](https://github.com/) 🤠

---

## ✨ Features
- 🗄 **Stashes** — Personal and/or shared
- 🐎 **Vehicle Trunk & Glovebox** — Includes optional horse saddlebag support
- 🔧 **Weapon Attachments** — Add or remove with ease
- 🏪 **Shops & Vending Machines** — Fully configurable
- 🎒 **Item Drops** — Physical objects in the world
- ⚖ **Configurable Limits** — Weight, slots, stash, and drop sizes
- 🚫 **Hotbar Spam Protection** — Adjustable timers and notifications

---

## 📜 Example Config
```lua
return {
    MaxWeight = 120000,
    MaxSlots = 40,
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
2. **Install** and start `ox_lib` and `rsg-core`  
3. Add `ensure rsg-inventory` to your `server.cfg`  
4. Edit `shared/config.lua` to fit your server’s needs

---

## 💎 Credits
- [**The Icon Library Project**](https://github.com/TankieTwitch/FREE-RedM-Image-Library) 🖼 — free RedM item icons

---

