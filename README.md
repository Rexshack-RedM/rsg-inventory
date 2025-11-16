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
- ⚖ **Configurable Limits** — Weight, slots, stash, and drop sizes  
- 🚫 **Hotbar Spam Protection** — Adjustable timers and notifications  

---

## 📸 Inventory Preview
<p align="center">
  <img src="https://cdn.discordapp.com/attachments/1109201552171864067/1405559539289559181/image.png?ex=689f44d4&is=689df354&hm=d50b6f578874f5e20e4d8f9858d13bba61eb8a246a08b9d6fc8c0ea83f52b68f&" 
       alt="Inventory Preview" 
       width="400">
</p>

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
2. **Install** and start `ox_lib` and `rsg-core` and  `rsg-shops` 
3. Add `ensure rsg-inventory` to your `server.cfg`  
4. Edit `shared/config.lua` to fit your server’s needs

---

## 💎 Credits
- [**The Icon Library Project**](https://github.com/TankieTwitch/FREE-RedM-Image-Library) 🖼 — free RedM item icons

---
