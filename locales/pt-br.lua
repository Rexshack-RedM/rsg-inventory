--[[
English base language translation for qb-inventory
Translation done by wanderrer (Martin Riggs#0807 on Discord)
]]--
local Translations = {
progress = {
    ["crafting"] = "Artesanato...",
},
notify = {
    ["failed"] = "Falhou",
    ["canceled"] = "Cancelado",
    ["vlocked"] = "Veículo Trancado",
    ["notowned"] = "Você não possui este item!",
    ["missitem"] = "Você não possui este item!",
    ["nonb"] = "Ninguém por perto!",
    ["noaccess"] = "Não Acessível",
    ["nosell"] = "Você não pode vender este item...",
    ["itemexist"] = "Item não existe??",
    ["notencash"] = "Você não possui dinheiro suficiente...",
    ["noitem"] = "Você não possui os itens corretos...",
    ["gsitem"] = "Você não pode se dar um item?",
    ["tftgitem"] = "Você está muito longe para dar itens!",
    ["infound"] = "Item que você tentou dar não encontrado!",
    ["iifound"] = "Item incorreto encontrado, tente novamente!",
    ["gitemrec"] = "Você Recebeu ",
    ["gitemfrom"] = " De ",
    ["gitemyg"] = "Você deu ",
    ["gitinvfull"] = "O inventário do outro jogador está cheio!",
    ["giymif"] = "Seu inventário está cheio!",
    ["gitydhei"] = "Você não possui itens suficientes",
    ["gitydhitt"] = "Você não possui itens suficientes para transferir",
    ["navt"] = "Tipo inválido...",
    ["anfoc"] = "Argumentos não preenchidos corretamente...",
    ["yhg"] = "Você deu ",
    ["cgitem"] = "Não é possível dar o item!",
    ["idne"] = "Item não existe",
    ["pdne"] = "Jogador não está online",
},
inf_mapping = {
    ["opn_inv"] = "Abrir Inventário",
    ["tog_slots"] = "Alternar espaços de teclas",
    ["use_item"] = "Usa o item no slot ",
},
menu = {
    ["vending"] = "Máquina de Venda",
    ["craft"] = "Artesanato",
    ["o_bag"] = "Abrir Bolsa",
},
interaction = {
    ["craft"] = "~g~E~w~ - Artesanato",
},
label = {
    ["craft"] = "Artesanato",
    ["a_craft"] = "Artesanato de Anexos",
},
}

if GetConvar('rsg_locale', 'en') == 'pt-br' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
