local Translations = {
    progress = {
        ['snowballs'] = 'Colecteaza bulgari de zapada..',
    },
    notify = {
        ['failed'] = 'Esuat',
        ['canceled'] = 'Anulat',
        ['vlocked'] = 'Vehicul Blocat',
        ['notowned'] = 'Nu detine acest obiect!',
        ['missitem'] = 'Nu are acest obiect!',
        ['nonb'] = 'Nimeni in apropiere!',
        ['noaccess'] = 'Nu este accesibil',
        ['nosell'] = 'Nu poate vinde acest obiect..',
        ['itemexist'] = 'Obiectul nu exista',
        ['notencash'] = 'Nu are suficienti bani..',
        ['noitem'] = 'Nu are obiectele corecte..',
        ['gsitem'] = 'Nu poate sa-si ofere un obiect?',
        ['tftgitem'] = 'Este prea departe pentru a da obiecte!',
        ['infound'] = 'Obiectul pe care a incercat sa-l ofere nu a fost gasit!',
        ['iifound'] = 'Obiect incorect gasit, incearca din nou!',
        ['gitemrec'] = 'A primit ',
        ['gitemfrom'] = ' De la ',
        ['gitemyg'] = 'A dat ',
        ['gitinvfull'] = 'Inventarul celorlalti jucatori este plin!',
        ['giymif'] = 'Inventarul lui este plin!',
        ['gitydhei'] = 'Nu are suficiente obiecte',
        ['gitydhitt'] = 'Nu are suficiente obiecte pentru a transfera',
        ['navt'] = 'Nu este un tip valid..',
        ['anfoc'] = 'Argumentele nu sunt completate corect..',
        ['yhg'] = 'A dat ',
        ['cgitem'] = 'Nu poate da obiect!',
        ['idne'] = 'Obiectul nu exista',
        ['pdne'] = 'Jucatorul nu este online',
    },
    inf_mapping = {
        ['opn_inv'] = 'Deschide Inventarul',
        ['tog_slots'] = 'Comuta sloturile de taste',
        ['use_item'] = 'Folosește obiectul din slot ',
    },
    menu = {
        ['vending'] = 'Automat de vanzare',
        ['bin'] = 'Deschide Pubela',
        ['craft'] = 'Mestesug',
        ['o_bag'] = 'Deschide Rucsacul',
    },
    interaction = {
        ['craft'] = '~g~E~w~ - Mestesug',
    },
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})