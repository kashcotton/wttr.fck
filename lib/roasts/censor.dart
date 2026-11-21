/// How filthy the app is allowed to be. Every line is written once at full
/// strength and filtered down, so all three levels stay equally funny.
enum Profanity { clean, salty, unhinged }

extension ProfanityLabel on Profanity {
  String get label => switch (this) {
        Profanity.clean => 'Clean',
        Profanity.salty => 'Salty',
        Profanity.unhinged => 'Unhinged',
      };
  String get blurb => switch (this) {
        Profanity.clean => 'Fudge, shoot, heck. Safe for grandma and the office.',
        Profanity.salty => 'Swears with the vowels starred out. F*ck yeah.',
        Profanity.unhinged => 'No filter. You were warned.',
      };
}

// Ordered longest-first so "motherfucker" wins over "fuck".
const _clean = <String, String>{
  'motherfucking': 'mother-trucking',
  'motherfucker': 'mother-trucker',
  'fucking': 'fudging',
  'fucked': 'fudged',
  'fucks': 'fudges',
  'fuck': 'fudge',
  'bullshit': 'baloney',
  'shitty': 'cruddy',
  'shitshow': 'circus',
  'shit': 'crud',
  'balls': 'heck',
  'assholes': 'buttheads',
  'asshole': 'butthead',
  'jackass': 'donkey',
  'dumbass': 'dummy',
  'ass': 'butt',
  'dickhead': 'doofus',
  'dick': 'jerk',
  'prick': 'jerk',
  'bitching': 'griping',
  'bitchy': 'grumpy',
  'bitch': 'grump',
  'bollocks': 'nonsense',
  'bloody': 'flipping',
  'wtf': 'wth',
  'goddamn': 'gosh-darn',
  'damn': 'darn',
  'hell': 'heck',
  'bastard': 'buster',
  'pissed': 'ticked',
  'piss': 'pee',
  'crap': 'crud',
};

// Salty keeps the mild stuff and stars the big ones.
const _salty = <String, String>{
  'motherfucking': 'motherf*cking',
  'motherfucker': 'motherf*cker',
  'fucking': 'f*cking',
  'fucked': 'f*cked',
  'fucks': 'f*cks',
  'fuck': 'f*ck',
  'bullshit': 'bullsh*t',
  'shitty': 'sh*tty',
  'shitshow': 'sh*tshow',
  'shit': 'sh*t',
  'assholes': 'a**holes',
  'asshole': 'a**hole',
  'dickhead': 'd*ckhead',
  'dick': 'd*ck',
  'bitching': 'b*tching',
  'bitchy': 'b*tchy',
  'bitch': 'b*tch',
};

final _pattern = RegExp(
  r'\b(' + _clean.keys.join('|') + r')\b',
  caseSensitive: false,
);

String censor(String text, Profanity level) {
  if (level == Profanity.unhinged) return text;
  final map = level == Profanity.clean ? _clean : _salty;
  return text.replaceAllMapped(_pattern, (m) {
    final word = m[0]!;
    final rep = map[word.toLowerCase()];
    if (rep == null) return word;
    if (word == word.toUpperCase() && word.length > 1) return rep.toUpperCase();
    if (word[0] == word[0].toUpperCase()) {
      return rep[0].toUpperCase() + rep.substring(1);
    }
    return rep;
  });
}
