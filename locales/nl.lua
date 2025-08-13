local Translations = {
    progress = {
        ['snowballs'] = 'Sneeuwballen verzamelen...',
    },
    notify = {
        ['failed'] = 'Mislukt',
        ['canceled'] = 'Geannuleerd',
        ['vlocked'] = 'Voertuig vergrendeld',
        ['notowned'] = 'Dit item is niet van jou!',
        ['missitem'] = 'Je hebt dit item niet!',
        ['nonb'] = 'Niemand in de buurt',
        ['noaccess'] = 'Geen toegang',
        ['nosell'] = 'Je kunt dit item niet verkopen',
        ['itemexist'] = 'Item bestaat niet',
        ['notencash'] = 'Je hebt niet genoeg contant geld',
        ['noitem'] = 'Je hebt de benodigde items niet',
        ['gsitem'] = 'Je kunt jezelf geen item geven',
        ['tftgitem'] = 'Je bent te ver weg om items te geven',
        ['infound'] = 'Het item dat je wilt geven is niet gevonden',
        ['iifound'] = 'Onjuist item gevonden, probeer opnieuw',
        ['gitemrec'] = 'Je hebt ontvangen: ',
        ['gitemfrom'] = ' van ',
        ['gitemyg'] = 'Je hebt gegeven: ',
        ['gitinvfull'] = 'De inventaris van de andere speler is vol',
        ['giymif'] = 'Jouw inventaris is vol',
        ['gitydhei'] = 'Je hebt niet genoeg van dit item',
        ['gitydhitt'] = 'Je hebt niet genoeg items om over te dragen',
        ['navt'] = 'Geen geldig type',
        ['anfoc'] = 'Argumenten niet correct ingevuld',
        ['yhg'] = 'Je hebt gegeven: ',
        ['cgitem'] = 'Kan item niet geven',
        ['idne'] = 'Item bestaat niet',
        ['pdne'] = 'Speler is niet online',
    },
    inf_mapping = {
        ['opn_inv'] = 'Open inventaris',
        ['tog_slots'] = 'Schakel sneltoets-slots om',
        ['use_item'] = 'Gebruik het item in slot ',
    },
    menu = {
        ['vending'] = 'Verkoopautomaat',
        ['bin'] = 'Open container',
        ['craft'] = 'Vervaardigen',
        ['o_bag'] = 'Open tas',
    },
    interaction = {
        ['craft'] = '~g~E~w~ - Vervaardigen',
    },
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true