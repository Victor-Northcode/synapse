/// Цензура ников в топе игроков.
///
/// Имена приходят из Game Center / Play Игр и с сетевой доски dreamlo —
/// то есть их пишут чужие люди, и там бывает что угодно. Каждое имя
/// прогоняется через фильтр; грязное имя подменяется ФЕЙКОВЫМ ником в
/// стиле игры (neon_fox384). Подмена детерминированная: один и тот же
/// игрок всегда виден под одним и тем же псевдонимом.
///
/// Фильтр ловит:
///  - мат на разных языках (рус/en/es/fr/de/it/pt/ja/ko/zh/ar);
///  - leet-маскировку: 3ае6ал, cyka, xyu, f_u_c_k, b1tch;
///  - транслит русского мата латиницей.
/// Ложное срабатывание безопасно: игрок просто показывается под
/// псевдонимом, счёт и ранг не меняются.
library;

import '../game/rivals.dart' show nickFromSeed;

/// Имя для показа в топе: исходное, если чистое, иначе фейковый ник.
String safeName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return nickFromSeed(1);
  return isProfane(name) ? nickFromSeed(_strHash(name)) : name;
}

/// Стабильный хэш строки — сид фейкового ника.
int _strHash(String s) {
  var h = 17;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  return h == 0 ? 1 : h;
}

bool isProfane(String raw) {
  final low = raw.toLowerCase();

  // 1. Нормализация: leet-цифры и диакритика → буквы.
  final norm = _mapChars(low, _leet);
  // 2. «Склейка»: убираем разделители — ловит f_u_c_k и х.у.й.
  final glued = norm.replaceAll(_nonLetter, '');
  // 3. Кириллический вариант: латинские двойники букв → кириллица
  //    (cyka → сука, 3ае6ал → заебал, xyu → хуи).
  final cyr = _mapChars(low, _toCyr).replaceAll(_nonLetter, '');

  for (final r in _roots) {
    if (glued.contains(r) || cyr.contains(r)) return true;
  }

  // 4. Отдельные слова — только целым токеном (иначе computadora,
  //    Dickinson или nazionale попали бы под нож).
  final tokens = <String>{
    ...norm.split(_nonLetter),
    ..._mapChars(low, _toCyr).split(_nonLetter),
  }..remove('');
  return tokens.any(_words.contains);
}

/// Всё, что не буква (латиница, кириллица, арабский, кана, CJK, хангыль).
final _nonLetter = RegExp(
    r'[^a-zа-яё؀-ۿ぀-ヿㇰ-ㇿ一-鿿가-힯]+');

String _mapChars(String s, Map<String, String> m) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(m[ch] ?? ch);
  }
  return b.toString();
}

/// Leet и диакритика → простые латинские буквы.
const _leet = {
  '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '8': 'b',
  '@': 'a', r'$': 's', '!': 'i', '+': 't',
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ß': 'ss', 'æ': 'ae',
  'ё': 'е',
};

/// Латинские двойники кириллицы (+ цифры-буквы) — для маскировок
/// вида cyka/xyu/3ае6ал, где мат набран смешанным алфавитом.
const _toCyr = {
  'a': 'а', 'b': 'в', 'c': 'с', 'e': 'е', 'i': 'и', 'k': 'к', 'm': 'м',
  'o': 'о', 'p': 'р', 't': 'т', 'x': 'х', 'y': 'у', 'u': 'и',
  '3': 'з', '0': 'о', '6': 'б', '4': 'ч',
  'ё': 'е',
};

/// Корни: срабатывают ПОДСТРОКОЙ в любом месте. Сюда попадают только
/// характерные последовательности, которых нет в нормальных словах.
const _roots = [
  // — русский (кириллица) —
  'хуй', 'хуе', 'хуя', 'хую', 'хуи', 'охуе', 'ахуе',
  'пизд', 'ебан', 'ебал', 'ебат', 'ебуч', 'ебло', 'еблан', 'ебарь',
  'заеб', 'наеб', 'доеб', 'уеб', 'долбо',
  'бляд', 'блят',
  'гандон', 'гондон', 'мудак', 'мудил', 'мандавош',
  'пидор', 'пидар', 'педрил', 'шлюх', 'шалав', 'залуп', 'дроч',
  'говн', 'сперм', 'сучк',
  // — русский транслитом —
  'blyat', 'blyad', 'pizd', 'pidor', 'pidar', 'dolboeb', 'eblan',
  'zalup', 'zaeb', 'gandon', 'gondon', 'shluha', 'shalav',
  'huyn', 'xuyn', 'ohuel', 'mudak',
  // — английский —
  'fuck', 'fuk', 'fck', 'fcuk', 'cunt', 'bitch', 'biatch', 'whore',
  'faggot', 'nigga', 'nigger', 'wank', 'asshole', 'arsehole',
  'dickhead', 'motherfuck', 'cocksuck', 'blowjob', 'handjob',
  'cumshot', 'porn', 'slut', 'twat', 'bullshit', 'shithead', 'shitty',
  // — испанский / португальский —
  'mierda', 'pendejo', 'maricon', 'caralho', 'buceta', 'arrombad',
  // — французский —
  'putain', 'salope', 'encul', 'connard', 'connasse',
  // — немецкий —
  'scheiss', 'fotze', 'hurensohn', 'arschloch', 'wichs', 'ficken',
  // — итальянский —
  'stronz', 'vaffancul', 'fanculo', 'puttana', 'cazzo', 'merda',
  // — японский —
  'まんこ', 'マンコ', 'ちんこ', 'チンコ', 'ちんぽ', 'チンポ', '死ね', 'くたばれ',
  // — корейский —
  '씨발', '씨빨', '병신', '좆', '개새끼', '지랄',
  // — китайский —
  '肏', '操你', '傻逼', '婊子', '屌你', '草泥马',
  // — арабский —
  'شرموط', 'عرص', 'منيوك', 'كسمك', 'كسامك',
];

/// Слова: срабатывают только ЦЕЛЫМ токеном — у этих корней слишком
/// много честных соседей (Dickinson, computadora, peacock, plébiscite).
const _words = {
  // — английский —
  'ass', 'dick', 'cock', 'cum', 'tits', 'pussy', 'anal', 'penis',
  'vagina', 'fag', 'fags', 'rape', 'raped', 'rapist', 'dildo',
  'shit', 'retard', 'retarded', 'nazi', 'hitler',
  // — испанский —
  'puta', 'puto', 'putas', 'joder', 'verga',
  // — французский —
  'pute', 'putes', 'nique', 'niquer', 'merde',
  // — португальский —
  'foda', 'foder',
  // — русский —
  'сука', 'суки', 'сучка', 'сучки', 'бля', 'ебу', 'педик',
  // — русский транслитом —
  'suka', 'blya', 'huy', 'hui', 'xui', 'xuy', 'ebat', 'yebat',
  'ebal', 'yebal', 'uebok', 'pidr',
};
