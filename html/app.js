const InventoryContainer = Vue.createApp({
    data() {
        return this.getInitialState();
    },
    computed: {
        playerWeight() {
            const weight = Object.values(this.playerInventory).reduce((total, item) => {
                if (item && item.weight !== undefined && item.amount !== undefined) {
                    return total + item.weight * item.amount;
                }
                return total;
            }, 0);
            return isNaN(weight) ? 0 : weight;
        },
        otherInventoryWeight() {
            const weight = Object.values(this.otherInventory).reduce((total, item) => {
                if (item && item.weight !== undefined && item.amount !== undefined) {
                    return total + item.weight * item.amount;
                }
                return total;
            }, 0);
            return isNaN(weight) ? 0 : weight;
        },
        weightBarClass() {
            const weightPercentage = (this.playerWeight / this.maxWeight) * 100;
            if (weightPercentage < 50) {
                return "low";
            } else if (weightPercentage < 75) {
                return "medium";
            } else {
                return "high";
            }
        },
        otherWeightBarClass() {
            const weightPercentage = (this.otherInventoryWeight / this.otherInventoryMaxWeight) * 100;
            if (weightPercentage < 50) {
                return "low";
            } else if (weightPercentage < 75) {
                return "medium";
            } else {
                return "high";
            }
        },
        shouldCenterInventory() {
            return this.isOtherInventoryEmpty;
        },
    },
    watch: {
        transferAmount(newVal) {
            if (newVal !== null && newVal < 1) this.transferAmount = 1;
        },
    },
    methods: {
        getInitialState() {
            return {
                // Config Options
                maxWeight: 0,
                totalSlots: 0,
                // Escape Key
                isInventoryOpen: false,
                additionalCloseKey: 'KeyI',
                // Single pane
                isOtherInventoryEmpty: true,
                // Error handling
                errorSlot: null,
                // Player Inventory
                playerInventory: {},
                inventoryLabel: "Inventory",
                playerName: "",
                totalWeight: 0,
                // Other inventory
                otherInventory: {},
                otherInventoryName: "",
                otherInventoryLabel: "Drop",
                otherInventoryMaxWeight: 1000000,
                otherInventorySlots: 100,
                isShopInventory: false,
                // Where item is coming from
                inventory: "",
                // Context Menu
                showContextMenu: false,
                contextMenuPosition: { top: "0px", left: "0px" },
                contextMenuItem: null,
                showSubmenu: false,
                // Hotbar
                showHotbar: false,
                hotbarItems: [],
                wasHotbarEnabled: false,
                // Notification box
                showNotification: false,
                notificationText: "",
                notificationImage: "",
                notificationType: "added",
                notificationAmount: 1,
                notificationTimeout: null,
                // Required items box
                //showRequiredItems: false,
                requiredItems: [],
                // Attachments
                selectedWeapon: null,
                showWeaponAttachments: false,
                selectedWeaponAttachments: [],
                // Dragging and dropping
                currentlyDraggingItem: null,
                currentlyDraggingSlot: null,
                dragStartX: 0,
                dragStartY: 0,
                ghostElement: null,
                dragStartInventoryType: "player",
                transferAmount: null,
                busy: false,
                dragThreshold: 5,
                isMouseDown: false,
                mouseDownX: 0,
                mouseDownY: 0,
            };
        },
        validateToken(csrfToken) {
            return axios
                .post("https://rsg-core/validateCSRF", {
                    clientToken: csrfToken,
                })
                .then((response) => {
                    return response.data.valid;
                })
                .catch((error) => {
                    console.error("Error validating CSRF:", error);
                    return false;
                });
        },
        openInventory(data) {
            if (this.showHotbar) {
                this.wasHotbarEnabled = true;
                this.toggleHotbar(false);
            } else {
                this.wasHotbarEnabled = false;
            }

            this.isInventoryOpen = true;
            this.maxWeight = data.maxweight;
            this.totalSlots = data.slots;
            this.playerInventory = {};
            this.otherInventory = {};

            // Add player name handling
            if (data.playerName) {
                this.playerName = data.playerName;
                this.inventoryLabel = this.playerName;
            } else {
                this.playerName = "Player";
                this.inventoryLabel = "Inventory";
            }

            if (data.inventory) {
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach((item) => {
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    });
                } else if (typeof data.inventory === "object") {
                    for (const key in data.inventory) {
                        const item = data.inventory[key];
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    }
                }
            }

            if (data.other) {
                if (data.other && data.other.inventory) {
                    if (Array.isArray(data.other.inventory)) {
                        data.other.inventory.forEach((item) => {
                            if (item && item.slot) {
                                this.otherInventory[item.slot] = item;
                            }
                        });
                    } else if (typeof data.other.inventory === "object") {
                        for (const key in data.other.inventory) {
                            const item = data.other.inventory[key];
                            if (item && item.slot) {
                                this.otherInventory[item.slot] = item;
                            }
                        }
                    }
                }

                this.otherInventoryName = data.other.name;
                this.otherInventoryLabel = data.other.label;
                this.otherInventoryMaxWeight = data.other.maxweight;
                this.otherInventorySlots = data.other.slots;

                if (this.otherInventoryName.startsWith("shop-")) {
                    this.isShopInventory = true;
                } else {
                    this.isShopInventory = false;
                }

                this.isOtherInventoryEmpty = false;
            }
        },
        updateInventory(data) {
            this.playerInventory = {};

            if (data.inventory) {
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach((item) => {
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    });
                } else if (typeof data.inventory === "object") {
                    for (const key in data.inventory) {
                        const item = data.inventory[key];
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    }
                }
            }
        },
        async closeInventory() {
            let inventoryName = this.otherInventoryName;
            const wasHotbarEnabled = this.wasHotbarEnabled;
            let hotbarItems = []
            if (wasHotbarEnabled) {
                hotbarItems = Array(5).fill(null).map((_, index) => {
                    const item = this.playerInventory[index + 1];
                    return item !== undefined ? item : null;
                });
            }

            Object.assign(this, this.getInitialState());
            try {
                await axios.post("https://rsg-inventory/CloseInventory", { name: inventoryName });
                if (wasHotbarEnabled) {
                    this.toggleHotbar({
                        open: true,
                        items: hotbarItems,
                    });
                }
            } catch (error) {
                console.error("Error closing inventory:", error);
            }
        },
        clearTransferAmount() {
            this.transferAmount = null;
        },
        getItemInSlot(slot, inventoryType) {
            if (inventoryType === "player") {
                return this.playerInventory[slot] || null;
            } else if (inventoryType === "other") {
                return this.otherInventory[slot] || null;
            }
            return null;
        },
        getHotbarItemInSlot(slot) {
            return this.hotbarItems[slot - 1] || null;
        },
        containerMouseDownAction(event) {
            if (event.button === 0 && this.showContextMenu) {
                this.showContextMenu = false;
            }
        },
        handleMouseDown(event, slot, inventory) {
            if (event.button === 1) return; // skip middle mouse
            event.preventDefault();
            const itemInSlot = this.getItemInSlot(slot, inventory);
            if (event.button === 0) {
                if (event.shiftKey && itemInSlot) {
                    this.splitAndPlaceItem(itemInSlot, inventory);
                } else {
                    this.isMouseDown = true;
                    this.mouseDownX = event.clientX;
                    this.mouseDownY = event.clientY;
                    this.currentlyDraggingSlot = slot;
                    this.dragStartInventoryType = inventory;
                }
            } else if (event.button === 2 && itemInSlot) {
                if (this.otherInventoryName.startsWith("shop-")) {
                    this.handlePurchase(itemInSlot.slot, itemInSlot, 1, inventory);
                    return;
                }
                if (!this.isOtherInventoryEmpty) {
                    this.moveItemBetweenInventories(itemInSlot, inventory);
                } else {
                    this.showContextMenuOptions(event, itemInSlot);
                }
            }
        },
        moveItemBetweenInventories(item, sourceInventoryType) {
            if (this.busy) {
                return;
            }

            this.busy = true;
            const sourceInventory = sourceInventoryType === "player" ? this.playerInventory : this.otherInventory;
            const targetInventory = sourceInventoryType === "player" ? this.otherInventory : this.playerInventory;
            const amountToTransfer = this.transferAmount !== null ? this.transferAmount : 1;
            let targetSlot = null;

            const sourceItem = sourceInventory[item.slot];
            if (!sourceItem || sourceItem.amount < amountToTransfer) {
                this.inventoryError(item.slot);
                this.busy = false;
                return;
            }

            const totalWeightAfterTransfer = this.otherInventoryWeight + sourceItem.weight * amountToTransfer;
            if (totalWeightAfterTransfer > this.otherInventoryMaxWeight) {
                this.inventoryError(item.slot);
                this.busy = false;
                return;
            }

            if (this.playerInventory != targetInventory) {
                if (this.findNextAvailableSlot(targetInventory) > this.otherInventorySlots) {
                    this.inventoryError(item.slot);
                    this.busy = false;
                    return;
                }
            }

            if (item.unique) {
                targetSlot = this.findNextAvailableSlot(targetInventory);
                if (targetSlot === null) {
                    this.inventoryError(item.slot);
                    this.busy = false;
                    return;
                }

                const newItem = {
                    ...item,
                    inventory: sourceInventoryType === "player" ? "other" : "player",
                    amount: amountToTransfer,
                };
                targetInventory[targetSlot] = newItem;
                newItem.slot = targetSlot;
            } else {
                const targetItemKey = Object.keys(targetInventory).find((key) => targetInventory[key] && targetInventory[key].name === item.name);
                const targetItem = targetInventory[targetItemKey];

                if (!targetItem) {
                    const newItem = {
                        ...item,
                        inventory: sourceInventoryType === "player" ? "other" : "player",
                        amount: amountToTransfer,
                    };

                    targetSlot = this.findNextAvailableSlot(targetInventory);
                    if (targetSlot === null) {
                        this.inventoryError(item.slot);
                        this.busy = false;
                        return;
                    }

                    targetInventory[targetSlot] = newItem;
                    newItem.slot = targetSlot;
                } else {
                    targetItem.amount += amountToTransfer;
                    targetSlot = targetItem.slot;
                }
            }

            sourceItem.amount -= amountToTransfer;

            if (sourceItem.amount <= 0) {
                delete sourceInventory[item.slot];
            }

            this.postInventoryData(sourceInventoryType, sourceInventoryType === "player" ? "other" : "player", item.slot, targetSlot, sourceItem.amount, amountToTransfer);
        },
        startDrag(event, slot, inventoryType) {
            event.preventDefault();
            const item = this.getItemInSlot(slot, inventoryType);
            if (!item) return;
            const slotElement = event.target.closest(".item-slot");
            if (!slotElement) return;
            this.dragStartInventoryType = inventoryType;
            const ghostElement = this.createGhostElement(slotElement);
            document.body.appendChild(ghostElement);
            const offsetX = ghostElement.offsetWidth / 2;
            const offsetY = ghostElement.offsetHeight / 2;
            ghostElement.style.left = `${event.clientX - offsetX}px`;
            ghostElement.style.top = `${event.clientY - offsetY}px`;
            this.ghostElement = ghostElement;
            this.currentlyDraggingItem = item;
            this.currentlyDraggingSlot = slot;
            this.dragStartX = event.clientX;
            this.dragStartY = event.clientY;
            this.showContextMenu = false;
        },
        createGhostElement(slotElement) {
            const ghostElement = slotElement.cloneNode(true);
            ghostElement.style.position = "absolute";
            ghostElement.style.pointerEvents = "none";
            ghostElement.style.opacity = "0.7";
            ghostElement.style.zIndex = "1000";
            ghostElement.style.width = getComputedStyle(slotElement).width;
            ghostElement.style.height = getComputedStyle(slotElement).height;
            ghostElement.style.boxSizing = "border-box";
            const amountElement = ghostElement.querySelector(".item-slot-amount p");
            if (amountElement) {
                const isShop = this.otherInventoryName.indexOf("shop-") !== -1;
                if (this.transferAmount) {
                    amountElement.textContent = `x${this.transferAmount}`;
                } else if (isShop && this.dragStartInventoryType == 'other') {
                    amountElement.textContent = `x1`;
                }
            }
            return ghostElement;
        },
        drag(event) {
            if (this.isMouseDown && !this.ghostElement) {
                const dx = Math.abs(event.clientX - this.mouseDownX);
                const dy = Math.abs(event.clientY - this.mouseDownY);
                if (dx >= this.dragThreshold || dy >= this.dragThreshold) {
                    this.startDrag(event, this.currentlyDraggingSlot, this.dragStartInventoryType);
                }
                return;
            }

            if (!this.currentlyDraggingItem || !this.ghostElement) return;

            const centeredX = event.clientX - this.ghostElement.offsetWidth / 2;
            const centeredY = event.clientY - this.ghostElement.offsetHeight / 2;
            this.ghostElement.style.left = `${centeredX}px`;
            this.ghostElement.style.top = `${centeredY}px`;
        },
        endDrag(event) {
            this.isMouseDown = false;
            if (!this.currentlyDraggingItem) {
                return;
            }
            const targetPlayerItemSlotElement = event.target.closest(".player-inventory .item-slot");
            if (targetPlayerItemSlotElement) {
                const targetSlot = Number(targetPlayerItemSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "player")) {
                    this.handleDropOnPlayerSlot(targetSlot);
                }
            }
            const targetOtherItemSlotElement = event.target.closest(".other-inventory .item-slot");
            if (targetOtherItemSlotElement) {
                const targetSlot = Number(targetOtherItemSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "other")) {
                    this.handleDropOnOtherSlot(targetSlot);
                }
            }
            const targetInventoryContainer = event.target.closest(".inventory-container");
            if (targetInventoryContainer && !targetPlayerItemSlotElement && !targetOtherItemSlotElement) {
                this.handleDropOnInventoryContainer();
            }
            this.clearDragData();
        },
        handleDropOnPlayerSlot(targetSlot) {
            if (this.isShopInventory && this.dragStartInventoryType === "other") {
                const { currentlyDraggingSlot, currentlyDraggingItem, transferAmount } = this;
                const targetInventory = this.getInventoryByType("player");
                const targetItem = targetInventory[targetSlot];
                if ((targetItem && targetItem.name !== currentlyDraggingItem.name)
                    || (targetItem && targetItem.name === currentlyDraggingItem.name && currentlyDraggingItem.unique)
                    || (targetItem && targetItem.name === currentlyDraggingItem.name && targetItem.info.quality && targetItem.info.quality !== 100)) {
                    this.inventoryError(currentlyDraggingSlot);
                    return;
                }
                this.handlePurchase(currentlyDraggingSlot, currentlyDraggingItem, transferAmount, this.dragStartInventoryType, targetSlot);
            } else {
                this.handleItemDrop("player", targetSlot);
            }
        },
        handleDropOnOtherSlot(targetSlot) {
            this.handleItemDrop("other", targetSlot);
        },
        async handleDropOnInventoryContainer() {
            if (this.isOtherInventoryEmpty && this.dragStartInventoryType === "player") {
                const newItem = {
                    ...this.currentlyDraggingItem,
                    amount: this.currentlyDraggingItem.amount,
                    slot: 1,
                    inventory: "other",
                };
                const draggingItem = this.currentlyDraggingItem;
                try {
                    const response = await axios.post("https://rsg-inventory/DropItem", {
                        ...newItem,
                        fromSlot: this.currentlyDraggingSlot,
                    });

                    if (response.data) {
                        this.otherInventory[1] = newItem;
                        const draggingItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key] === draggingItem);
                        if (draggingItemKey) {
                            delete this.playerInventory[draggingItemKey];
                        }
                        this.otherInventoryName = response.data;
                        this.otherInventoryLabel = response.data;
                        this.isOtherInventoryEmpty = false;
                        this.clearDragData();
                    }
                } catch (error) {
                    this.inventoryError(this.currentlyDraggingSlot);
                }
            }
            this.clearDragData();
        },
        clearDragData() {
            if (this.ghostElement) {
                document.body.removeChild(this.ghostElement);
                this.ghostElement = null;
            }
            this.currentlyDraggingItem = null;
            this.currentlyDraggingSlot = null;
        },
        getInventoryByType(inventoryType) {
            return inventoryType === "player" ? this.playerInventory : this.otherInventory;
        },
        handleItemDrop(targetInventoryType, targetSlot) {
            try {
                const isShop = this.otherInventoryName.indexOf("shop-");
                if (this.dragStartInventoryType === "other" && targetInventoryType === "other" && isShop !== -1) {
                    return;
                }

                const targetSlotNumber = parseInt(targetSlot, 10);
                if (isNaN(targetSlotNumber)) {
                    throw new Error("Invalid target slot number");
                }

                const sourceInventory = this.getInventoryByType(this.dragStartInventoryType);
                const targetInventory = this.getInventoryByType(targetInventoryType);

                const sourceItem = sourceInventory[this.currentlyDraggingSlot];
                if (!sourceItem) {
                    throw new Error("No item in the source slot to transfer");
                }

                const amountToTransfer = this.transferAmount !== null ? this.transferAmount : sourceItem.amount;
                if (sourceItem.amount < amountToTransfer) {
                    throw new Error("Insufficient amount of item in source inventory");
                }

                if (this.dragStartInventoryType === "player" && targetInventoryType === "other" && isShop !== -1) {
                    this.handlePurchase(
                        this.currentlyDraggingSlot,
                        sourceItem,
                        this.transferAmount !== null ? this.transferAmount : sourceItem.amount,
                        this.dragStartInventoryType)
                    return;
                }

                if (targetInventoryType !== this.dragStartInventoryType) {
                    if (targetInventoryType == "other") {
                        const totalWeightAfterTransfer = this.otherInventoryWeight + sourceItem.weight * amountToTransfer;
                        if (totalWeightAfterTransfer > this.otherInventoryMaxWeight) {
                            throw new Error("Insufficient weight capacity in target inventory");
                        }
                    }
                    else if (targetInventoryType == "player") {
                        const totalWeightAfterTransfer = this.playerWeight + sourceItem.weight * amountToTransfer;
                        if (totalWeightAfterTransfer > this.maxWeight) {
                            throw new Error("Insufficient weight capacity in player inventory");
                        }
                    }
                }

                const targetItem = targetInventory[targetSlotNumber];

                if (targetItem) {
                    if (sourceItem.name === targetItem.name && targetItem.unique) {
                        this.inventoryError(this.currentlyDraggingSlot);
                        return;
                    }
                    if (sourceItem.name === targetItem.name && !targetItem.unique && sourceItem.info.quality == targetItem.info.quality) {
                        targetItem.amount += amountToTransfer;
                        sourceItem.amount -= amountToTransfer;
                        if (sourceItem.amount <= 0) {
                            delete sourceInventory[this.currentlyDraggingSlot];
                        }
                        this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, targetSlotNumber, sourceItem.amount, amountToTransfer);
                    } else {
                        sourceInventory[this.currentlyDraggingSlot] = targetItem;
                        targetInventory[targetSlotNumber] = sourceItem;
                        sourceInventory[this.currentlyDraggingSlot].slot = this.currentlyDraggingSlot;
                        targetInventory[targetSlotNumber].slot = targetSlotNumber;
                        this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, targetSlotNumber, sourceItem.amount, targetItem.amount);
                    }
                } else {
                    sourceItem.amount -= amountToTransfer;
                    if (sourceItem.amount <= 0) {
                        delete sourceInventory[this.currentlyDraggingSlot];
                    }
                    targetInventory[targetSlotNumber] = { ...sourceItem, amount: amountToTransfer, slot: targetSlotNumber };
                    this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, targetSlotNumber, sourceItem.amount, amountToTransfer);
                }
            } catch (error) {
                console.error(error.message);
                this.inventoryError(this.currentlyDraggingSlot);
            } finally {
                this.clearDragData();
            }
        },
        async handlePurchase(sourceSlot, sourceItem, transferAmount, sourceInventoryType, targetSlot = null) {
            if (this.busy) {
                return;
            }

            if (sourceItem.amount < 1) {
                this.inventoryError(sourceSlot);
                return;
            }

            this.busy = true;
            try {
                const response = await axios.post("https://rsg-inventory/AttemptPurchase", {
                    item: sourceItem,
                    amount: transferAmount || 1,
                    shop: this.otherInventoryName,
                    sourceinvtype: sourceInventoryType,
                    targetslot: targetSlot,
                });

                if (response.data) {
                    if (!sourceItem.amount) {
                        this.busy = false;
                        return;
                    }

                    const amountToTransfer = transferAmount !== null ? transferAmount : 1;
                    if (sourceInventoryType == 'player') {
                        for (const key in this.otherInventory) {
                            const item = this.otherInventory[key];
                            if (item.name == sourceItem.name && item.amount) {
                                this.otherInventory[key].amount += amountToTransfer
                                break
                            }
                        }
                    } else {
                        if (sourceItem.amount < amountToTransfer) {
                            this.inventoryError(sourceSlot);
                            this.busy = false;
                            return;
                        }
                        sourceItem.amount -= amountToTransfer;
                    }

                    this.busy = false;
                } else {
                    this.inventoryError(sourceSlot);
                    this.busy = false;
                }
            } catch (error) {
                this.inventoryError(sourceSlot);
                this.busy = false;
            }
        },
        async dropItem(item, quantity) {
            if (item && item.name) {
                const playerItemKey = Object.keys(this.playerInventory).find((key) =>
                    this.playerInventory[key] && this.playerInventory[key].slot === item.slot
                );

                if (playerItemKey) {
                    let amountToGive;

                    if (typeof quantity === "string") {
                        switch (quantity) {
                            case "half":
                                amountToGive = Math.ceil(item.amount / 2);
                                break;
                            case "all":
                                amountToGive = item.amount;
                                break;
                            case "enteramount":
                                const amounttt = await axios.post("https://rsg-inventory/GiveItemAmount")
                                amountToGive = amounttt.data;
                                break;
                            default:
                                console.error("Invalid quantity specified.");
                                return;
                        }
                    } else if (typeof quantity === "number" && quantity > 0) {
                        amountToGive = quantity;
                    } else {
                        console.error("Invalid quantity type specified.");
                        return;
                    }

                    if (amountToGive > item.amount) {
                        amountToGive = item.amount;
                    }

                    const newItem = {
                        ...item,
                        amount: amountToGive,
                        slot: 1,
                        inventory: "other",
                    };

                    try {
                        const response = await axios.post("https://rsg-inventory/DropItem", {
                            ...newItem,
                            fromSlot: item.slot,
                        });

                        if (response.data) {
                            const remainingAmount = this.playerInventory[playerItemKey].amount - amountToGive;
                            if (remainingAmount <= 0) {
                                delete this.playerInventory[playerItemKey];
                            } else {
                                this.playerInventory[playerItemKey].amount = remainingAmount;
                            }

                            this.otherInventory[1] = newItem;
                            this.otherInventoryName = response.data;
                            this.otherInventoryLabel = response.data;
                            this.isOtherInventoryEmpty = false;
                        }
                    } catch (error) {
                        this.inventoryError(item.slot);
                    }
                }
            }
            this.showContextMenu = false;
        },
        async useItem(item) {
            if (!item || item.useable === false) {
                return;
            }
            const playerItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key] && this.playerInventory[key].slot === item.slot);
            if (playerItemKey) {
                try {
                    if (item.shouldClose) {
                        this.closeInventory();
                    }
                    await axios.post("https://rsg-inventory/UseItem", {
                        inventory: "player",
                        item: item,
                    });
                } catch (error) {
                    console.error("Error using the item: ", error);
                }
            }
            this.showContextMenu = false;
        },
        showContextMenuOptions(event, item) {
            event.preventDefault();
            if (this.contextMenuItem && this.contextMenuItem.name === item.name && this.showContextMenu) {
                this.showContextMenu = false;
                this.contextMenuItem = null;
            } else {
                if (item.inventory === "other") {
                    const matchingItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key].name === item.name);
                    const matchingItem = this.playerInventory[matchingItemKey];

                    if (matchingItem && matchingItem.unique) {
                        const newItemKey = Object.keys(this.playerInventory).length + 1;
                        const newItem = {
                            ...item,
                            inventory: "player",
                            amount: 1,
                        };
                        this.playerInventory[newItemKey] = newItem;
                    } else if (matchingItem) {
                        matchingItem.amount++;
                    } else {
                        const newItemKey = Object.keys(this.playerInventory).length + 1;
                        const newItem = {
                            ...item,
                            inventory: "player",
                            amount: 1,
                        };
                        this.playerInventory[newItemKey] = newItem;
                    }
                    item.amount--;

                    if (item.amount <= 0) {
                        const itemKey = Object.keys(this.otherInventory).find((key) => this.otherInventory[key] === item);
                        if (itemKey) {
                            delete this.otherInventory[itemKey];
                        }
                    }
                }
                const menuLeft = event.clientX;
                const menuTop = event.clientY;
                this.showContextMenu = true;
                this.contextMenuPosition = {
                    top: `${menuTop}px`,
                    left: `${menuLeft}px`,
                };
                this.contextMenuItem = item;
            }
        },
        async giveItem(item, quantity) {
            if (item && item.name) {
                const selectedItem = item;
                const playerHasItem = Object.values(this.playerInventory).some((invItem) => invItem && invItem.name === selectedItem.name);

                if (playerHasItem) {
                    let amountToGive;
                    if (typeof quantity === "string") {
                        switch (quantity) {
                            case "half":
                                amountToGive = Math.ceil(selectedItem.amount / 2);
                                break;
                            case "all":
                                amountToGive = selectedItem.amount;
                                break;
                            case "enteramount":
                                const amounttt = await axios.post("https://rsg-inventory/GiveItemAmount")
                                amountToGive = amounttt.data;
                                break;
                            default:
                                console.error("Invalid quantity specified.");
                                return;
                        }
                    } else {
                        amountToGive = quantity;
                    }

                    if (amountToGive > selectedItem.amount) {
                        console.error("Specified quantity exceeds available amount.");
                        return;
                    }

                    try {
                        const response = await axios.post("https://rsg-inventory/GiveItem", {
                            item: selectedItem,
                            amount: amountToGive,
                            slot: selectedItem.slot,
                            info: selectedItem.info,
                        });
                        if (!response.data) return;

                        this.playerInventory[selectedItem.slot].amount -= amountToGive;
                        if (this.playerInventory[selectedItem.slot].amount === 0) {
                            delete this.playerInventory[selectedItem.slot];
                        }
                    } catch (error) {
                        console.error("An error occurred while giving the item:", error);
                    }
                } else {
                    console.error("Player does not have the item in their inventory. Item cannot be given.");
                }
            }
            this.showContextMenu = false;
        },
        findNextAvailableSlot(inventory) {
            for (let slot = 1; slot <= this.totalSlots; slot++) {
                if (!inventory[slot]) {
                    return slot;
                }
            }
            return null;
        },
        async splitAndPlaceItem(item, inventoryType, splitamount = 'half') {
            const inventoryRef = inventoryType === "player" ? this.playerInventory : this.otherInventory;
            let amount = 1;
            if (item && item.amount > 1) {
                if (splitamount == 'half') {
                    amount = Math.ceil(item.amount / 2);
                } else if (splitamount == 'enteramount') {
                    const inputAmount = await axios.post("https://rsg-inventory/GiveItemAmount")
                    amount = inputAmount.data;

                    if (amount < 1) {
                        amount = 1;
                    } else if (amount > item.amount) {
                        amount = item.amount;
                    }
                }

                const originalSlot = Object.keys(inventoryRef).find((key) => inventoryRef[key] === item);
                if (originalSlot !== undefined) {
                    const newItem = { ...item, amount: amount };
                    const nextSlot = this.findNextAvailableSlot(inventoryRef);
                    if (nextSlot !== null) {
                        inventoryRef[nextSlot] = newItem;
                        inventoryRef[originalSlot] = { ...item, amount: item.amount - amount };
                        this.postInventoryData(inventoryType, inventoryType, originalSlot, nextSlot, item.amount, newItem.amount);
                    }
                }
            }
            this.showContextMenu = false;
        },
        toggleHotbar(data) {
            if (data.open) {
                this.hotbarItems = data.items;
                this.showHotbar = true;
            } else {
                this.showHotbar = false;
                this.hotbarItems = [];
            }
        },
        showItemNotification(itemData) {
            this.notificationText = itemData.item.label;
            this.notificationImage = "images/" + itemData.item.image;
            this.notificationType = itemData.type === "add" ? "Received" : itemData.type === "use" ? "Used" : "Removed";
            this.notificationAmount = itemData.amount || 1;
            this.showNotification = true;

            if (this.notificationTimeout) {
                clearTimeout(this.notificationTimeout);
            }

            this.notificationTimeout = setTimeout(() => {
                this.showNotification = false;
                this.notificationTimeout = null;
            }, 3000);
        },
        /* showRequiredItem(data) {
            if (data.toggle) {
                this.requiredItems = data.items;
                this.showRequiredItems = true;
            } else {
                setTimeout(() => {
                    this.showRequiredItems = false;
                    this.requiredItems = [];
                }, 100);
            }
        }, */
        inventoryError(slot) {
            const slotElement = document.getElementById(`slot-${slot}`);
            if (slotElement) {
                slotElement.style.backgroundColor = "red";
            }
            axios.post("https://rsg-inventory/PlayDropFail", {}).catch((error) => {
                console.error("Error playing drop fail:", error);
            });
            setTimeout(() => {
                if (slotElement) {
                    slotElement.style.backgroundColor = "";
                }
            }, 1000);
        },
        copySerial() {
            if (!this.contextMenuItem) {
                return;
            }
            const item = this.contextMenuItem;
            if (item) {
                const el = document.createElement("textarea");
                el.value = item.info.serie;
                document.body.appendChild(el);
                el.select();
                document.execCommand("copy");
                document.body.removeChild(el);
            }
        },
        /* openWeaponAttachments() {
            if (!this.contextMenuItem) {
                return;
            }
            if (!this.showWeaponAttachments) {
                this.selectedWeapon = this.contextMenuItem;
                this.showWeaponAttachments = true;
                axios
                    .post("https://rsg-inventory/GetWeaponData", JSON.stringify({ weapon: this.selectedWeapon.name, ItemData: this.selectedWeapon }))
                    .then((response) => {
                        const data = response.data;
                        if (data.AttachmentData !== null && data.AttachmentData !== undefined) {
                            if (data.AttachmentData.length > 0) {
                                this.selectedWeaponAttachments = data.AttachmentData;
                            }
                        }
                    })
                    .catch((error) => {
                        console.error(error);
                    });
            } else {
                this.showWeaponAttachments = false;
                this.selectedWeapon = null;
                this.selectedWeaponAttachments = [];
            }
        },
        removeAttachment(attachment) {
            if (!this.selectedWeapon) {
                return;
            }
            const index = this.selectedWeaponAttachments.indexOf(attachment);
            if (index !== -1) {
                this.selectedWeaponAttachments.splice(index, 1);
            }
            axios
                .post("https://rsg-inventory/RemoveAttachment", JSON.stringify({ AttachmentData: attachment, WeaponData: this.selectedWeapon }))
                .then((response) => {
                    this.selectedWeapon = response.data.WeaponData;
                    if (response.data.Attachments) {
                        this.selectedWeaponAttachments = response.data.Attachments;
                    }
                    const nextSlot = this.findNextAvailableSlot(this.playerInventory);
                    if (nextSlot !== null) {
                        response.data.itemInfo.amount = 1;
                        this.playerInventory[nextSlot] = response.data.itemInfo;
                    }
                })
                .catch((error) => {
                    console.error(error);
                    this.selectedWeaponAttachments.splice(index, 0, attachment);
                });
        }, */
        generateTooltipContent(item) {
            if (!item) {
                return "";
            }
            let content = `<div class="custom-tooltip"><div class="tooltip-header">${item.label}</div><hr class="tooltip-divider">`;
        
            const description = item.info?.description?.replace(/\n/g, "<br>") 
                || item.description?.replace(/\n/g, "<br>") 
                || "No description available.";
        
            const renderInfo = (obj, indent = 0) => {
                let html = "";
                for (const [key, value] of Object.entries(obj)) {
                    if (key === "description" || key === "lastUpdate" || key === "componentshash" || key === "components") continue;
        
                    const padding = "&nbsp;".repeat(indent * 4);

                    if (typeof value === "object" && value !== null && !Array.isArray(value)) {
                        html += `<div class="tooltip-info"><span class="tooltip-info-key">${padding}${this.formatKey(key)}:</span></div>`;
                        html += renderInfo(value, indent + 1);
                    } else {
                        html += `<div class="tooltip-info"><span class="tooltip-info-key">${padding}${this.formatKey(key)}:</span> ${value}</div>`;
                    }
                }
                return html;
            };
            
            if (item.info && Object.keys(item.info).length > 0) {
                content += renderInfo(item.info);
            }
        
            content += `<div class="tooltip-description">${description}</div>`;
            content += `<div class="tooltip-weight"><i class="fas fa-weight-hanging"></i> ${item.weight != null ? (item.weight / 1000).toFixed(1) : "N/A"}kg</div>`;
            content += `</div>`;
        
            return content;
        },
        formatKey(key) {
            return key.replace(/_/g, " ").charAt(0).toUpperCase() + key.slice(1);
        },
        postInventoryData(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount) {
            this.busy = true;
            let fromInventoryName = fromInventory === "other" ? this.otherInventoryName : fromInventory;
            let toInventoryName = toInventory === "other" ? this.otherInventoryName : toInventory;

            axios
                .post("https://rsg-inventory/SetInventoryData", {
                    fromInventory: fromInventoryName,
                    toInventory: toInventoryName,
                    fromSlot,
                    toSlot,
                    fromAmount,
                    toAmount,
                })
                .then((response) => {
                    this.clearDragData();
                    this.busy = false;
                })
                .catch((error) => {
                    console.error("Error posting inventory data:", error);
                    this.busy = false;
                });
        },
    },
    mounted() {
        window.addEventListener("keyup", (event) => {
            const code = event.code;
            if (code === "Escape" || code === "Tab" || code === this.additionalCloseKey) {
                if (this.isInventoryOpen) {
                    this.closeInventory();
                }
            }
        });

        window.addEventListener("message", async (event) => {
            switch (event.data.action) {
                case "open":
                    let isValid = await this.validateToken(event.data.token)
                    if (isValid) {
                        this.openInventory(event.data);
                    }
                    break;
                case "close":
                    this.closeInventory();
                    break;
                case "update":
                    if (this.validateToken(event.data.token)) {
                        this.updateInventory(event.data);
                    }
                    break;
                case "toggleHotbar":
                    if (this.validateToken(event.data.token)) {
                        this.toggleHotbar(event.data);
                    }
                    break;
                case "itemBox":
                    this.showItemNotification(event.data);
                    break;
                /* case "requiredItem":
                    this.showRequiredItem(event.data);
                    break; */
                case "updateHotbar":
                    if (this.validateToken(event.data.token)) {
                        this.hotbarItems = event.data.items;
                    }
                    break;
                default:
                    console.warn(`Unexpected action: ${event.data.action}`);
            }
        });
    },
    beforeUnmount() {
        window.removeEventListener("mousemove", () => { });
        window.removeEventListener("keydown", () => { });
        window.removeEventListener("message", () => { });
    },
});

InventoryContainer.use(FloatingVue);
InventoryContainer.mount("#app");
