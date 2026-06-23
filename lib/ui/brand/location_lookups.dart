import '../../gen_l10n/app_localizations.dart';

const _countryOrder = <String>[
  'russia',
  'australia',
  'austria',
  'belarus',
  'belgium',
  'bulgaria',
  'uk',
  'germany',
  'greece',
  'georgia',
  'spain',
  'italy',
  'kazakhstan',
  'canada',
  'cyprus',
  'netherlands',
  'uae',
  'poland',
  'portugal',
  'usa',
  'turkey',
  'uzbekistan',
  'france',
  'czechia',
  'switzerland',
];

const _citiesByCountry = <String, List<String>>{
  'russia': [
    'moscow',
    'saint_petersburg',
    'kazan',
    'yekaterinburg',
    'novosibirsk',
    'sochi',
    'krasnodar',
    'rostov_on_don',
    'nizhny_novgorod',
    'samara',
    'ufa',
    'vladivostok',
  ],
  'australia': [
    'sydney',
    'melbourne',
    'brisbane',
    'perth',
    'adelaide',
    'gold_coast',
    'canberra',
  ],
  'austria': ['vienna', 'salzburg', 'graz', 'innsbruck', 'linz'],
  'belarus': ['minsk', 'brest', 'grodno', 'vitebsk', 'gomel'],
  'belgium': ['brussels', 'antwerp', 'ghent', 'bruges', 'liege'],
  'bulgaria': ['sofia', 'varna', 'burgas', 'plovdiv'],
  'uk': [
    'london',
    'manchester',
    'liverpool',
    'birmingham',
    'edinburgh',
    'glasgow',
  ],
  'germany': [
    'berlin',
    'munich',
    'hamburg',
    'frankfurt',
    'cologne',
    'dusseldorf',
    'stuttgart',
  ],
  'greece': ['athens', 'thessaloniki', 'heraklion', 'patras'],
  'georgia': ['tbilisi', 'batumi', 'kutaisi'],
  'spain': [
    'madrid',
    'barcelona',
    'valencia',
    'seville',
    'malaga',
    'alicante',
    'ibiza',
  ],
  'italy': [
    'rome',
    'milan',
    'florence',
    'venice',
    'naples',
    'turin',
    'bologna',
  ],
  'kazakhstan': ['almaty', 'astana', 'shymkent', 'karaganda', 'atyrau'],
  'canada': ['toronto', 'vancouver', 'montreal', 'calgary', 'ottawa'],
  'cyprus': ['nicosia', 'limassol', 'larnaca', 'paphos'],
  'netherlands': [
    'amsterdam',
    'rotterdam',
    'the_hague',
    'utrecht',
    'eindhoven',
  ],
  'uae': ['dubai', 'abu_dhabi', 'sharjah', 'ajman'],
  'poland': ['warsaw', 'krakow', 'wroclaw', 'gdansk', 'poznan'],
  'portugal': ['lisbon', 'porto', 'faro', 'braga'],
  'usa': [
    'new_york',
    'los_angeles',
    'miami',
    'chicago',
    'las_vegas',
    'san_francisco',
    'boston',
    'houston',
  ],
  'turkey': ['istanbul', 'ankara', 'izmir', 'antalya', 'bodrum'],
  'uzbekistan': ['tashkent', 'samarkand', 'bukhara'],
  'france': ['paris', 'nice', 'lyon', 'marseille', 'cannes', 'bordeaux'],
  'czechia': ['prague', 'brno', 'ostrava', 'karlovy_vary'],
  'switzerland': ['zurich', 'geneva', 'basel', 'lausanne', 'bern'],
};

const _countryAliases = <String, List<String>>{
  'russia': ['россия', 'russia'],
  'australia': ['австралия', 'australia'],
  'austria': ['австрия', 'austria'],
  'belarus': ['беларусь', 'belarus'],
  'belgium': ['бельгия', 'belgium'],
  'bulgaria': ['болгария', 'bulgaria'],
  'uk': ['великобритания', 'united kingdom', 'uk', 'great britain'],
  'germany': ['германия', 'germany'],
  'greece': ['греция', 'greece'],
  'georgia': ['грузия', 'georgia'],
  'spain': ['испания', 'spain'],
  'italy': ['италия', 'italy'],
  'kazakhstan': ['казахстан', 'kazakhstan'],
  'canada': ['канада', 'canada'],
  'cyprus': ['кипр', 'cyprus'],
  'netherlands': ['нидерланды', 'netherlands', 'holland'],
  'uae': ['оаэ', 'uae', 'united arab emirates'],
  'poland': ['польша', 'poland'],
  'portugal': ['португалия', 'portugal'],
  'usa': ['сша', 'usa', 'united states', 'united states of america'],
  'turkey': ['турция', 'turkey'],
  'uzbekistan': ['узбекистан', 'uzbekistan'],
  'france': ['франция', 'france'],
  'czechia': ['чехия', 'czechia', 'czech republic'],
  'switzerland': ['швейцария', 'switzerland'],
};

List<String> countryOptions(AppLocalizations t) {
  return _countryOrder
      .map((id) => _countryLabel(t, id))
      .toList(growable: false);
}

List<String> cityOptionsForCountry(AppLocalizations t, String country) {
  final countryId = _resolveCountryId(t, country);
  if (countryId == null) return const <String>[];

  final cityIds = _citiesByCountry[countryId] ?? const <String>[];
  return cityIds.map((id) => _cityLabel(t, id)).toList(growable: false);
}

String? _resolveCountryId(AppLocalizations t, String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  for (final id in _countryOrder) {
    final localized = _countryLabel(t, id).trim().toLowerCase();
    if (localized == normalized) return id;

    final aliases = _countryAliases[id] ?? const <String>[];
    if (aliases.contains(normalized)) return id;
  }

  return null;
}

String _countryLabel(AppLocalizations t, String id) {
  switch (id) {
    case 'russia':
      return t.countryRussia;
    case 'australia':
      return t.countryAustralia;
    case 'austria':
      return t.countryAustria;
    case 'belarus':
      return t.countryBelarus;
    case 'belgium':
      return t.countryBelgium;
    case 'bulgaria':
      return t.countryBulgaria;
    case 'uk':
      return t.countryUnitedKingdom;
    case 'germany':
      return t.countryGermany;
    case 'greece':
      return t.countryGreece;
    case 'georgia':
      return t.countryGeorgia;
    case 'spain':
      return t.countrySpain;
    case 'italy':
      return t.countryItaly;
    case 'kazakhstan':
      return t.countryKazakhstan;
    case 'canada':
      return t.countryCanada;
    case 'cyprus':
      return t.countryCyprus;
    case 'netherlands':
      return t.countryNetherlands;
    case 'uae':
      return t.countryUae;
    case 'poland':
      return t.countryPoland;
    case 'portugal':
      return t.countryPortugal;
    case 'usa':
      return t.countryUsa;
    case 'turkey':
      return t.countryTurkey;
    case 'uzbekistan':
      return t.countryUzbekistan;
    case 'france':
      return t.countryFrance;
    case 'czechia':
      return t.countryCzechia;
    case 'switzerland':
      return t.countrySwitzerland;
    default:
      return id;
  }
}

String _cityLabel(AppLocalizations t, String id) {
  switch (id) {
    case 'moscow':
      return t.cityMoscow;
    case 'saint_petersburg':
      return t.citySaintPetersburg;
    case 'kazan':
      return t.cityKazan;
    case 'yekaterinburg':
      return t.cityYekaterinburg;
    case 'novosibirsk':
      return t.cityNovosibirsk;
    case 'sochi':
      return t.citySochi;
    case 'krasnodar':
      return t.cityKrasnodar;
    case 'rostov_on_don':
      return t.cityRostovOnDon;
    case 'nizhny_novgorod':
      return t.cityNizhnyNovgorod;
    case 'samara':
      return t.citySamara;
    case 'ufa':
      return t.cityUfa;
    case 'vladivostok':
      return t.cityVladivostok;
    case 'sydney':
      return t.citySydney;
    case 'melbourne':
      return t.cityMelbourne;
    case 'brisbane':
      return t.cityBrisbane;
    case 'perth':
      return t.cityPerth;
    case 'adelaide':
      return t.cityAdelaide;
    case 'gold_coast':
      return t.cityGoldCoast;
    case 'canberra':
      return t.cityCanberra;
    case 'vienna':
      return t.cityVienna;
    case 'salzburg':
      return t.citySalzburg;
    case 'graz':
      return t.cityGraz;
    case 'innsbruck':
      return t.cityInnsbruck;
    case 'linz':
      return t.cityLinz;
    case 'minsk':
      return t.cityMinsk;
    case 'brest':
      return t.cityBrest;
    case 'grodno':
      return t.cityGrodno;
    case 'vitebsk':
      return t.cityVitebsk;
    case 'gomel':
      return t.cityGomel;
    case 'brussels':
      return t.cityBrussels;
    case 'antwerp':
      return t.cityAntwerp;
    case 'ghent':
      return t.cityGhent;
    case 'bruges':
      return t.cityBruges;
    case 'liege':
      return t.cityLiege;
    case 'sofia':
      return t.citySofia;
    case 'varna':
      return t.cityVarna;
    case 'burgas':
      return t.cityBurgas;
    case 'plovdiv':
      return t.cityPlovdiv;
    case 'london':
      return t.cityLondon;
    case 'manchester':
      return t.cityManchester;
    case 'liverpool':
      return t.cityLiverpool;
    case 'birmingham':
      return t.cityBirmingham;
    case 'edinburgh':
      return t.cityEdinburgh;
    case 'glasgow':
      return t.cityGlasgow;
    case 'berlin':
      return t.cityBerlin;
    case 'munich':
      return t.cityMunich;
    case 'hamburg':
      return t.cityHamburg;
    case 'frankfurt':
      return t.cityFrankfurt;
    case 'cologne':
      return t.cityCologne;
    case 'dusseldorf':
      return t.cityDusseldorf;
    case 'stuttgart':
      return t.cityStuttgart;
    case 'athens':
      return t.cityAthens;
    case 'thessaloniki':
      return t.cityThessaloniki;
    case 'heraklion':
      return t.cityHeraklion;
    case 'patras':
      return t.cityPatras;
    case 'tbilisi':
      return t.cityTbilisi;
    case 'batumi':
      return t.cityBatumi;
    case 'kutaisi':
      return t.cityKutaisi;
    case 'madrid':
      return t.cityMadrid;
    case 'barcelona':
      return t.cityBarcelona;
    case 'valencia':
      return t.cityValencia;
    case 'seville':
      return t.citySeville;
    case 'malaga':
      return t.cityMalaga;
    case 'alicante':
      return t.cityAlicante;
    case 'ibiza':
      return t.cityIbiza;
    case 'rome':
      return t.cityRome;
    case 'milan':
      return t.cityMilan;
    case 'florence':
      return t.cityFlorence;
    case 'venice':
      return t.cityVenice;
    case 'naples':
      return t.cityNaples;
    case 'turin':
      return t.cityTurin;
    case 'bologna':
      return t.cityBologna;
    case 'almaty':
      return t.cityAlmaty;
    case 'astana':
      return t.cityAstana;
    case 'shymkent':
      return t.cityShymkent;
    case 'karaganda':
      return t.cityKaraganda;
    case 'atyrau':
      return t.cityAtyrau;
    case 'toronto':
      return t.cityToronto;
    case 'vancouver':
      return t.cityVancouver;
    case 'montreal':
      return t.cityMontreal;
    case 'calgary':
      return t.cityCalgary;
    case 'ottawa':
      return t.cityOttawa;
    case 'nicosia':
      return t.cityNicosia;
    case 'limassol':
      return t.cityLimassol;
    case 'larnaca':
      return t.cityLarnaca;
    case 'paphos':
      return t.cityPaphos;
    case 'amsterdam':
      return t.cityAmsterdam;
    case 'rotterdam':
      return t.cityRotterdam;
    case 'the_hague':
      return t.cityTheHague;
    case 'utrecht':
      return t.cityUtrecht;
    case 'eindhoven':
      return t.cityEindhoven;
    case 'dubai':
      return t.cityDubai;
    case 'abu_dhabi':
      return t.cityAbuDhabi;
    case 'sharjah':
      return t.citySharjah;
    case 'ajman':
      return t.cityAjman;
    case 'warsaw':
      return t.cityWarsaw;
    case 'krakow':
      return t.cityKrakow;
    case 'wroclaw':
      return t.cityWroclaw;
    case 'gdansk':
      return t.cityGdansk;
    case 'poznan':
      return t.cityPoznan;
    case 'lisbon':
      return t.cityLisbon;
    case 'porto':
      return t.cityPorto;
    case 'faro':
      return t.cityFaro;
    case 'braga':
      return t.cityBraga;
    case 'new_york':
      return t.cityNewYork;
    case 'los_angeles':
      return t.cityLosAngeles;
    case 'miami':
      return t.cityMiami;
    case 'chicago':
      return t.cityChicago;
    case 'las_vegas':
      return t.cityLasVegas;
    case 'san_francisco':
      return t.citySanFrancisco;
    case 'boston':
      return t.cityBoston;
    case 'houston':
      return t.cityHouston;
    case 'istanbul':
      return t.cityIstanbul;
    case 'ankara':
      return t.cityAnkara;
    case 'izmir':
      return t.cityIzmir;
    case 'antalya':
      return t.cityAntalya;
    case 'bodrum':
      return t.cityBodrum;
    case 'tashkent':
      return t.cityTashkent;
    case 'samarkand':
      return t.citySamarkand;
    case 'bukhara':
      return t.cityBukhara;
    case 'paris':
      return t.cityParis;
    case 'nice':
      return t.cityNice;
    case 'lyon':
      return t.cityLyon;
    case 'marseille':
      return t.cityMarseille;
    case 'cannes':
      return t.cityCannes;
    case 'bordeaux':
      return t.cityBordeaux;
    case 'prague':
      return t.cityPrague;
    case 'brno':
      return t.cityBrno;
    case 'ostrava':
      return t.cityOstrava;
    case 'karlovy_vary':
      return t.cityKarlovyVary;
    case 'zurich':
      return t.cityZurich;
    case 'geneva':
      return t.cityGeneva;
    case 'basel':
      return t.cityBasel;
    case 'lausanne':
      return t.cityLausanne;
    case 'bern':
      return t.cityBern;
    default:
      return id;
  }
}
