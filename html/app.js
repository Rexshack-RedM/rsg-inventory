const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-inventory';
const $ = (id) => document.getElementById(id);

let labels = {};
const L = (key, fallback) => labels[key] || fallback;

function applyLabels() {
    document.querySelectorAll('[data-l]').forEach((el) => {
        if (labels[el.dataset.l]) el.textContent = labels[el.dataset.l];
    });
    document.querySelectorAll('[data-l-title]').forEach((el) => {
        if (labels[el.dataset.lTitle]) el.title = labels[el.dataset.lTitle];
    });
}

const state = {
    open: false,
    imagePath: '',
    hotbarSlots: 5,
    player: null,
    other: null,
    drag: null,
};

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
}

// Lua tables may arrive as arrays (with nulls) or objects keyed by slot
function bySlot(items) {
    const map = {};
    if (!items) return map;
    Object.values(items).forEach((it) => { if (it && it.slot) map[it.slot] = it; });
    return map;
}

function totalWeight(map) {
    return Object.values(map).reduce((w, it) => w + (it.weight || 0) * (it.amount || 0), 0);
}

const kg = (g) => (g / 1000).toFixed(1);
const imgSrc = (it) => state.imagePath + (it.image || `${it.name}.png`);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/* ------------------------------------------------------------------ render */
function setWeight(prefix, inv) {
    const used = totalWeight(inv.map);
    const pct = inv.maxWeight > 0 ? Math.min(100, (used / inv.maxWeight) * 100) : 0;
    $(`${prefix}-weight`).textContent = kg(used);
    $(`${prefix}-max`).textContent = kg(inv.maxWeight || 0);
    const bar = $(`${prefix}-bar`);
    bar.style.width = pct + '%';
    bar.className = 'fill ' + (pct < 70 ? 'stat-good' : pct < 90 ? 'stat-warn' : 'stat-bad');
}

function slotEl(invKey, slot, item, showKey) {
    const el = document.createElement('div');
    el.className = 'slot' + (item ? ' filled' : '') + (showKey ? ' hot' : '');
    el.dataset.inv = invKey;
    el.dataset.slot = slot;
    let html = showKey ? `<div class="key">${slot}</div>` : '';
    if (item) {
        html += `<img src="${esc(imgSrc(item))}" onerror="this.style.visibility='hidden'">`;
        html += `<div class="qty">${item.amount > 1 ? 'x' + item.amount : ''}</div>`;
        if (item.price !== undefined && invKey === 'other') html += `<div class="price">$${Number(item.price).toFixed(2)}</div>`;
        const q = item.info && typeof item.info.quality === 'number' ? item.info.quality : null;
        if (q !== null) {
            const cls = q > 60 ? 'stat-good' : q > 25 ? 'stat-warn' : 'stat-bad';
            html += `<div class="quality ${cls}" style="width:calc((100% - 8px) * ${Math.max(0, Math.min(100, q)) / 100})"></div>`;
        }
        html += `<div class="name">${esc(item.label)}</div>`;
    }
    el.innerHTML = html;
    return el;
}

/* ------------------------------------------------------------------ category filter */
const filters = { player: 'all', other: 'all' };
let categoryLabels = {};

const categoryOf = (item) => item.category || 'misc';

function categoryLabel(cat) {
    if (cat === 'all') return L('ui_all', 'All');
    if (cat === 'misc') return L('ui_misc', 'Misc');
    return categoryLabels[cat] || String(cat).replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
}

function renderFilters(invKey) {
    const inv = state[invKey];
    const bar = $(`filter-${invKey}`);
    const cats = [...new Set(Object.values(inv.map).map(categoryOf))].sort();
    // reset a filter whose category no longer exists in this inventory
    if (filters[invKey] !== 'all' && !cats.includes(filters[invKey])) filters[invKey] = 'all';
    bar.classList.toggle('hidden', cats.length < 2);
    bar.innerHTML = ['all', ...cats].map((c) =>
        `<button class="chip${filters[invKey] === c ? ' active' : ''}" data-filter="${esc(c)}" data-inv="${invKey}">${esc(categoryLabel(c))}</button>`
    ).join('');
}

function renderGrid(invKey) {
    const inv = state[invKey];
    const grid = $(`grid-${invKey}`);
    grid.innerHTML = '';
    if (!inv) return;
    renderFilters(invKey);
    const f = filters[invKey];
    let shown = 0;
    for (let s = 1; s <= inv.slots; s++) {
        const item = inv.map[s];
        // filtered view: only matching items (empty slots hidden)
        if (f !== 'all' && (!item || categoryOf(item) !== f)) continue;
        grid.appendChild(slotEl(invKey, s, item, invKey === 'player' && s <= state.hotbarSlots));
        shown++;
    }
    if (f !== 'all' && shown === 0) {
        grid.innerHTML = `<div class="grid-empty">${esc(L('ui_no_matches', 'No items in this category'))}</div>`;
    }
}

document.addEventListener('click', (e) => {
    const chip = e.target.closest('.chip[data-filter]');
    if (!chip) return;
    filters[chip.dataset.inv] = chip.dataset.filter;
    renderGrid(chip.dataset.inv);
});

function render() {
    if (state.player) {
        $('player-label').textContent = state.player.label || L('ui_satchel', 'Satchel');
        setWeight('player', state.player);
        renderGrid('player');
    }
    const other = state.other;
    $('panel-other').classList.toggle('hidden', !other);
    if (other) {
        $('other-label').textContent = other.label || L('ui_ground', 'Ground');
        const subs = {
            stash: L('ui_storage', 'Storage'),
            shop: L('ui_shop_hint', 'Drag to buy · drop here to sell'),
            player: L('ui_searching', 'Searching'),
        };
        $('other-sub').textContent = subs[other.type] || L('ui_drop_here', 'Drop items here');
        $('panel-other').querySelector('.weight').classList.toggle('hidden', other.type === 'shop');
        if (other.type !== 'shop') setWeight('other', other);
        renderGrid('other');
    }
}

function setInv(key, data) {
    if (data === false) { state[key] = null; return; }
    if (!data) return; // undefined/null = unchanged
    state[key] = { ...data, map: bySlot(data.items) };
}

/* ------------------------------------------------------------------ info */
function showInfo(item) {
    if (!item) return;
    $('info-title').textContent = item.label;
    $('info-desc').textContent = item.description || '';
    const rows = [`<div><span>${L('ui_weight', 'Weight')}</span>${kg((item.weight || 0) * (item.amount || 1))} ${esc(L('ui_kg', 'kg'))}</div>`];
    if (item.price !== undefined) rows.push(`<div><span>${L('ui_price', 'Price')}</span>$${Number(item.price).toFixed(2)}</div>`);
    if (item.buyPrice !== undefined) rows.push(`<div><span>${L('ui_sells_for', 'Sells for')}</span>$${Number(item.buyPrice).toFixed(2)}</div>`);
    const info = item.info || {};
    Object.keys(info).forEach((k) => {
        const v = info[k];
        if (v === null || typeof v === 'object') return;
        rows.push(`<div><span>${esc(L('info_' + k, k))}</span>${esc(v)}</div>`);
    });
    $('info-meta').innerHTML = rows.join('');
}

/* ------------------------------------------------------------------ drag */
function invId(key) {
    if (key === 'player') return 'player';
    return state.other ? state.other.id : null;
}

function getItem(key, slot) {
    const inv = state[key];
    return inv ? inv.map[slot] : null;
}

function requestedAmount(item, half, key) {
    const isShop = key === 'other' && state.other && state.other.type === 'shop';
    const v = parseInt($('amount').value, 10);
    if (isShop) return v > 0 ? v : 1;
    if (half) return Math.max(1, Math.floor(item.amount / 2));
    if (!v || v <= 0 || v > item.amount) return item.amount;
    return v;
}

function firstFreeSlot(key, name) {
    const inv = state[key];
    if (!inv) return null;
    for (let s = 1; s <= inv.slots; s++) {
        const it = inv.map[s];
        if (it && it.name === name && !it.unique) return s;
    }
    for (let s = 1; s <= inv.slots; s++) if (!inv.map[s]) return s;
    return null;
}

function move(fromKey, fromSlot, toKey, toSlot, amount) {
    const from = invId(fromKey), to = invId(toKey);
    if (!from || !to) return;
    post('move', { from, to, fromSlot, toSlot, amount });
}

document.addEventListener('mousedown', (e) => {
    const el = e.target.closest('.slot.filled');
    if (!el || !state.open || el.closest('#hotbar')) return;
    const key = el.dataset.inv, slot = +el.dataset.slot;
    const item = getItem(key, slot);
    if (!item) return;

    if (e.button === 2) { // right click: context menu
        openMenu(e.clientX, e.clientY, key, slot, item);
        return;
    }
    if (e.button !== 0) return;

    if (e.ctrlKey) { // quick move
        const target = key === 'player' ? 'other' : 'player';
        if (!state[target]) return;
        const to = state[target].type === 'shop' ? 1 : firstFreeSlot(target, item.name);
        if (to) move(key, slot, target, to, requestedAmount(item, e.shiftKey, key));
        return;
    }

    state.drag = { key, slot, item, amount: requestedAmount(item, e.shiftKey, key), el, startX: e.clientX, startY: e.clientY, active: false };
});

document.addEventListener('mousemove', (e) => {
    const d = state.drag;
    if (!d) return;
    if (!d.active) {
        if (Math.abs(e.clientX - d.startX) + Math.abs(e.clientY - d.startY) < 5) return;
        d.active = true;
        d.el.classList.add('dragging');
        const g = $('ghost');
        g.innerHTML = `<img src="${esc(imgSrc(d.item))}"><div class="qty">x${d.amount}</div>`;
        g.classList.remove('hidden');
    }
    const g = $('ghost');
    g.style.left = (e.clientX - 35) + 'px';
    g.style.top = (e.clientY - 35) + 'px';
    document.querySelectorAll('.drag-over').forEach((n) => n.classList.remove('drag-over'));
    const over = document.elementFromPoint(e.clientX, e.clientY);
    const target = over && (over.closest('#app .slot') || over.closest('.drop-zone'));
    if (target) target.classList.add('drag-over');
});

document.addEventListener('mouseup', (e) => {
    const d = state.drag;
    state.drag = null;
    if (!d) return;
    $('ghost').classList.add('hidden');
    d.el.classList.remove('dragging');
    document.querySelectorAll('.drag-over').forEach((n) => n.classList.remove('drag-over'));
    if (!d.active) return;

    const over = document.elementFromPoint(e.clientX, e.clientY);
    if (!over) return;

    const zone = over.closest('.drop-zone');
    if (zone) {
        if (d.key !== 'player') return;
        if (zone.dataset.zone === 'use') post('use', { slot: d.slot });
        if (zone.dataset.zone === 'give') post('give', { slot: d.slot, amount: d.amount });
        return;
    }

    const slotEl = over.closest('#app .slot');
    if (!slotEl) return;
    const toKey = slotEl.dataset.inv, toSlot = +slotEl.dataset.slot;
    if (toKey === d.key && toSlot === d.slot) return;
    move(d.key, d.slot, toKey, toSlot, d.amount);
});

document.addEventListener('contextmenu', (e) => e.preventDefault());

document.addEventListener('dblclick', (e) => {
    const el = e.target.closest('#grid-player .slot.filled');
    if (el) post('use', { slot: +el.dataset.slot });
});

document.addEventListener('mouseover', (e) => {
    const el = e.target.closest('#app .slot.filled');
    if (el) showInfo(getItem(el.dataset.inv, +el.dataset.slot));
});

document.addEventListener('click', (e) => {
    if (e.target.closest('[data-action="close"]')) post('close');
});

document.addEventListener('keyup', (e) => {
    if (!state.open) return;
    if (!$('amount-modal').classList.contains('hidden')) {
        if (e.key === 'Escape') closeAmountModal();
        if (e.key === 'Enter') confirmAmountModal();
        return;
    }
    if (!$('ctx').classList.contains('hidden') && e.key === 'Escape') return closeMenu();
    if (document.activeElement === $('amount') && e.key !== 'Escape') return;
    if (e.key === 'Escape' || e.key === 'Tab' || e.key.toLowerCase() === 'i') post('close');
});

/* ------------------------------------------------------------------ right-click menu */
function firstEmptySlot(key) {
    const inv = state[key];
    if (!inv) return null;
    for (let s = 1; s <= inv.slots; s++) if (!inv.map[s]) return s;
    return null;
}

const half = (n) => Math.max(1, Math.floor(n / 2));

// amount picker: n | 'half' | 'all' | 'ask'
function withAmount(item, choice, fn, max) {
    max = max || item.amount || 1;
    if (choice === 'ask') return openAmountModal(item, max, fn);
    const n = choice === 'all' ? max : choice === 'half' ? half(max) : choice;
    fn(Math.min(Math.max(1, n), max));
}

function amountSub(item, fn, opts = {}) {
    const max = opts.max || item.amount || 1;
    const subs = [{ label: L('ui_one', 'One'), run: () => withAmount(item, 1, fn, max) }];
    if (!opts.noHalf && max > 1) subs.push({ label: L('ui_half', 'Half'), run: () => withAmount(item, 'half', fn, max) });
    if (!opts.noAll && max > 1) subs.push({ label: L('ui_all_amount', 'All'), run: () => withAmount(item, 'all', fn, max) });
    subs.push({ label: L('ui_enter_amount', 'Amount…'), run: () => withAmount(item, 'ask', fn, max) });
    return subs;
}

function buildMenu(key, slot, item) {
    const other = state.other;
    const otherKey = key === 'player' ? 'other' : 'player';
    const entries = [];
    const isShop = key === 'other' && other && other.type === 'shop';

    if (isShop) {
        entries.push({ label: L('ui_buy', 'Buy'), sub: amountSub(item, (n) => {
            const to = firstFreeSlot('player', item.name);
            if (to) move('other', slot, 'player', to, n);
        }, { max: item.amount || 1000, noAll: !item.amount, noHalf: true }) });
        return entries;
    }

    if (key === 'player') {
        if (item.useable || item.type === 'weapon' || item.type === 'weapon_thrown' || item.type === 'equipment') {
            entries.push({ label: L('ui_use', 'Use'), run: () => post('use', { slot }) });
        }
        entries.push({ label: L('ui_give', 'Give'), sub: amountSub(item, (n) => post('give', { slot, amount: n })) });
        entries.push({ label: L('ui_drop', 'Drop'), sub: amountSub(item, (n) => post('drop', { slot, amount: n })) });
    }

    if (other && other.type !== 'shop') {
        const label = key === 'player' ? L('ui_move_to', 'Move to') + ' ' + (other.label || L('ui_ground', 'Ground'))
                                       : L('ui_take', 'Take');
        entries.push({ label, sub: amountSub(item, (n) => {
            const to = firstFreeSlot(otherKey, item.name);
            if (to) move(key, slot, otherKey, to, n);
        }) });
    } else if (key === 'player' && other && other.type === 'shop') {
        entries.push({ label: L('ui_sell', 'Sell'), sub: amountSub(item, (n) => move('player', slot, 'other', 1, n)) });
    }

    if (!item.unique && item.amount > 1) {
        entries.push({ label: L('ui_split', 'Split'), sub: amountSub(item, (n) => {
            const to = firstEmptySlot(key);
            if (to) move(key, slot, key, to, n);
        }, { noAll: true, max: item.amount - 1 }) });
    }

    if (item.info && item.info.serie) {
        entries.push({ label: L('ui_copy_serial', 'Copy serial'), run: () => copyText(item.info.serie) });
    }
    return entries;
}

function copyText(text) {
    const t = document.createElement('textarea');
    t.value = text;
    document.body.appendChild(t);
    t.select();
    try { document.execCommand('copy'); } catch (err) { /* ignore */ }
    t.remove();
}

function renderMenuList(list, entries) {
    list.innerHTML = '';
    entries.forEach((en) => {
        const li = document.createElement('li');
        li.textContent = en.label;
        if (en.sub) {
            li.classList.add('has-sub');
            const sub = document.createElement('ul');
            sub.className = 'ctx-sub';
            renderMenuList(sub, en.sub);
            li.appendChild(sub);
        } else {
            li.addEventListener('click', (ev) => { ev.stopPropagation(); closeMenu(); en.run(); });
        }
        list.appendChild(li);
    });
}

function openMenu(x, y, key, slot, item) {
    const entries = buildMenu(key, slot, item);
    if (!entries.length) return;
    const menu = $('ctx');
    $('ctx-title').textContent = item.label;
    renderMenuList($('ctx-list'), entries);
    menu.classList.remove('hidden', 'flip');
    const w = menu.offsetWidth, h = menu.offsetHeight;
    const left = Math.min(x, window.innerWidth - w - 8);
    menu.style.left = left + 'px';
    menu.style.top = Math.min(y, window.innerHeight - h - 8) + 'px';
    // open submenus to the left when there is no room on the right
    if (left + w * 2 > window.innerWidth) menu.classList.add('flip');
}

function closeMenu() { $('ctx').classList.add('hidden'); }

document.addEventListener('mousedown', (e) => {
    if (!e.target.closest('#ctx')) closeMenu();
}, true);

/* ------------------------------------------------------------------ amount modal */
let amountCb = null, amountMax = 1;
function openAmountModal(item, max, cb) {
    amountCb = cb; amountMax = max;
    $('amount-modal-title').textContent = item.label;
    $('amount-modal-max').textContent = `${L('ui_max', 'Max')}: ${max}`;
    const input = $('amount-modal-input');
    input.max = max; input.value = 1;
    $('amount-modal').classList.remove('hidden');
    setTimeout(() => { input.focus(); input.select(); }, 0);
}
function closeAmountModal() { $('amount-modal').classList.add('hidden'); amountCb = null; }
function confirmAmountModal() {
    const n = parseInt($('amount-modal-input').value, 10);
    const cb = amountCb;
    closeAmountModal();
    if (cb && n > 0) cb(Math.min(n, amountMax));
}
document.addEventListener('click', (e) => {
    if (e.target.closest('[data-modal="confirm"]')) confirmAmountModal();
    if (e.target.closest('[data-modal="cancel"]')) closeAmountModal();
});

/* ------------------------------------------------------------------ hotbar */
let hotbarTimer = null;
function showHotbar(items) {
    const bar = $('hotbar');
    bar.innerHTML = '';
    const map = bySlot(items);
    for (let s = 1; s <= state.hotbarSlots; s++) bar.appendChild(slotEl('hotbar', s, map[s], true));
    bar.classList.remove('hidden');
    clearTimeout(hotbarTimer);
    hotbarTimer = setTimeout(() => bar.classList.add('hidden'), 3000);
}

/* ------------------------------------------------------------------ item box */
const itemBoxRecent = {};
function showItemBox(d) {
    if (!d || !d.item) return;
    // de-dupe: scripts often call RemoveItem AND trigger their own ItemBox, and the
    // inventory also sends a 'use' box — show one box per item/action burst
    const now = Date.now(), name = d.item.name;
    const seen = (k) => now - (itemBoxRecent[name + ':' + k] || 0) < 1000;
    if (seen(d.kind)) return;
    if (d.kind === 'use' && seen('remove')) return;
    if (d.kind === 'remove' && seen('use')) return;
    itemBoxRecent[name + ':' + d.kind] = now;
    if (d.imagePath) state.imagePath = d.imagePath;
    const box = document.createElement('div');
    box.className = `itembox itembox-${d.kind}`;
    const qty = d.kind === 'use' ? '' : `${d.amount}x `;
    box.innerHTML = `<div class="itembox-action">${esc(d.text || d.kind)}</div>
        <img src="${esc(imgSrc(d.item))}" onerror="this.style.visibility='hidden'">
        <div class="itembox-label">${esc(qty + (d.item.label || d.item.name))}</div>`;
    const c = $('itembox-container');
    c.className = 'pos-' + (d.position || 'bottom');
    c.appendChild(box);
    while (c.children.length > 5) c.firstChild.remove();
    setTimeout(() => box.classList.add('out'), 2600);
    setTimeout(() => box.remove(), 3000);
}

/* ------------------------------------------------------------------ messages */
window.addEventListener('message', ({ data: msg }) => {
    const d = msg.data || {};
    switch (msg.action) {
        case 'open':
            state.open = true;
            state.imagePath = d.imagePath || state.imagePath;
            state.hotbarSlots = d.hotbarSlots || 5;
            state.other = null;
            if (d.labels) labels = d.labels;
            categoryLabels = d.categoryLabels || {};
            filters.other = 'all';
            applyLabels();
            $('info-title').textContent = '—';
            $('info-meta').innerHTML = '';
            setInv('player', d.player);
            setInv('other', d.other);
            $('amount').value = 0;
            $('hotbar').classList.add('hidden');
            $('app').classList.remove('hidden');
            render();
            break;
        case 'refresh':
            setInv('player', d.player);
            setInv('other', d.other);
            render();
            break;
        case 'close':
            closeMenu();
            closeAmountModal();
            state.open = false;
            state.drag = null;
            $('ghost').classList.add('hidden');
            $('app').classList.add('hidden');
            break;
        case 'hotbar':
            state.imagePath = d.imagePath || state.imagePath;
            showHotbar(d.items);
            break;
        case 'itembox':
            showItemBox(d);
            break;
    }
});
