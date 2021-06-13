/// Normalizes text according to [SPDX guidelines v2.1][]
///
/// [SPDX guidelines v2.1] : https://github.com/spdx/spdx-spec/blo b/v2.2/chapters/appendix-II-license-matching-guidelines-and-templates.md
String normalize(String text) {
  // Guideline 4.1.1: upper case and lower case letters should be treated as lower case letters
  text = text.toLowerCase();

  text = text.replaceAll(_newLineRegex, '\n');

  // Guideline 3.1.1: All whitespace should be treated as a single blank space.
  text = text.replaceAll(_horizontalWhiteSpaceRegex, ' ');

  // Guideline 5: Equivalent Punctuation marks
  _equivalentPunctuationMarks.forEach((reg, value) {
    text = text.replaceAll(reg, value);
  });

  // Guideline 8.1.1: Legally equal words must be treated same.
  _varietalWords.forEach((key, value) {
    text = text.replaceAll(RegExp(key), value);
  });

  // Guideline 2.1.4: Omitable texts that can be ignored.
  text = _removeOmmitableText(text);
  return text;
}

final _horizontalWhiteSpaceRegex = RegExp(r'[^\S\r\n]+');
final _newLineRegex = RegExp('[\r\u0085]');

/// Words obtained from [https://github.com/spdx/license-list-XML/blob/master/equivalentwords.txt]
final _varietalWords = {
  'acknowledgment': 'acknowledgement',
  'analogue': 'analog',
  'analyse': 'analyze',
  'artefact': 'artifact',
  'authorization': 'authorisation',
  'authorized': 'authorised',
  'calibre': 'caliber',
  'canceled': 'cancelled',
  'capitalizations': 'capitalisations',
  'catalogue': 'catalog',
  'categorise': 'categorize',
  'centre': 'center',
  'copyright holder': 'copyright owner',
  'emphasised': 'emphasized',
  'favor': 'favour',
  'favorite': 'favourite',
  'fulfil': 'fulfill',
  'fulfillment': 'fulfilment',
  'initialise': 'initialize',
  'judgment': 'judgement',
  'labelling': 'labeling',
  'labor': 'labour',
  'licence': 'license',
  'maximize': 'maximise',
  'modelled': 'modeled',
  'modelling': 'modeling',
  'non-commercial': 'noncommercial',
  'offence': 'offense',
  'optimise': 'optimize',
  'organization': 'organisation',
  'organize': 'organise',
  'per cent': 'percent',
  'practice': 'practise',
  'programme': 'program',
  'realise': 'realize',
  'recognise': 'recognize',
  'signalling': 'signaling',
  'sub-license': 'sublicense',
  'sub license': 'sublicense',
  'utilisation': 'utilization',
  'whilst': 'while',
  'wilful': 'wilfull',
  'http:': 'https',
};

final Map<RegExp, String> _equivalentPunctuationMarks = {
  // Guideline 5.1.2: All variants of dashes considered equivalent.
  RegExp(r'[-֊־᠆‐‑–—﹘﹣－‒⁃⁻⎯─⏤]'): '-',

  // Guideline Guideline 5.1.3: All variants of quotations considered equivalent.
  RegExp(r'[“‟”’"‘‛❛❜〝〞«»‹›❝❞]'): "'",

  // Guideline 9.1.1: ©, (c) considered equivalent.
  RegExp(r'©'): '(c)'
};

final _ignorableRegex = [
  RegExp(r'^(all|some) rights? reserved\.?', caseSensitive: false),
  RegExp(
      r'^(.{1,4})?copyright (\(c\) )?(\[?\d{4}\]?|y{4})(-\[?\d{4}\]? |-y{4} )?[,.]?.*$',
      caseSensitive: false),
  RegExp(r'^\s*$'),
  RegExp(r'^(.{1,4})?version \d(\.\d)*(,.*)?$', caseSensitive: false),
  RegExp(r'^(.{1,4})?copyright (\(c\) )?<?year>? <?(copyright )?owners?>?.*$',
      caseSensitive: false),
  RegExp(r'^(.{1,4})?copyright (notice|and permission notice)$',
      caseSensitive: false),
  RegExp(r'^\d{4}-[a-z]{3}-\d{1,2}$', caseSensitive: false),
  RegExp(r'^\d{2}/\d{2}/\d{4}$'),
];

//
String _removeOmmitableText(String text) {
  var lines = text.split('\n');
  var cleanedLines = <String>[];

  for (var i = 0; i < lines.length; i++) {
    var match = false;
    for (var j = 0; j < _ignorableRegex.length; j++) {
      if (_ignorableRegex[j].hasMatch(lines[i].trim())) {
        match = true;
        break;
      }
    }
    if (!match) {
      cleanedLines.add(lines[i]);
    } else {
      cleanedLines.add('');
    }
  }

  return cleanedLines.join('\n');
}
