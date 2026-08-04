import 'package:flutter_test/flutter_test.dart';
import 'package:synapse/core/name_filter.dart';

void main() {
  test('мат на разных языках подменяется фейковым ником', () {
    const dirty = [
      // русский и кириллица
      'хуй123', 'ПиЗдЕц', 'ЗаЕбал', 'бля', 'сука', 'долбоеб_99',
      'гандон', 'шлюха_топ', 'охуенный',
      // маскировка: leet, смешанный алфавит, разделители
      'cyka', '3ае6ал', 'xyu', 'f_u_c_k', 'b1tch', 'F.U.C.K.99',
      'blyat_master', 'pizdec',
      // английский
      'fuckboy', 'BitchKing', 'asshole1', 'NiggaPro', 'slutty',
      // испанский / французский / немецкий / итальянский
      'mierda_uno', 'putain75', 'Arschloch', 'cazzone', 'salope!',
      'hurensohn_x', 'pendejo22',
      // токены-слова
      'puta', 'dick', 'shit', 'nazi', 'hitler', 'педик',
      // азиатские и арабский
      '씨발놈', '병신王', 'まんこちゃん', '傻逼玩家', 'شرموطة',
    ];
    for (final n in dirty) {
      expect(isProfane(n), true, reason: '«$n» должен быть отцензурен');
      final s = safeName(n);
      expect(s, isNot(n), reason: '«$n» должен подмениться');
      expect(s, matches(RegExp(r'^[a-z]+_?[a-z]+\d+$')),
          reason: 'фейк для «$n» должен быть ником в стиле игры, а не «$s»');
    }
  });

  test('честные имена не трогаются (включая коварные)', () {
    const clean = [
      'neon_fox384', 'Alex', 'Мария2000', 'DragonSlayer', 'ProGamer',
      // содержат «опасные» куски внутри честных слов
      'Dickinson', 'Hitchcock', 'Peacock', 'computadora', 'nazionale',
      'Debater', 'cucumber', 'huitre', 'Сукачёв', 'WangHui',
      'assistant', 'classic', 'Cassandra', 'grape_fan', 'canal_9',
      'Analytics', 'плебисцит', 'команда1', 'сукно',
      '山田太郎', '김철수', 'محمد',
    ];
    for (final n in clean) {
      expect(isProfane(n), false, reason: '«$n» честное имя');
      expect(safeName(n), n, reason: '«$n» не должно подменяться');
    }
  });

  test('подмена детерминированная: один игрок — один псевдоним', () {
    final a = safeName('fuckboy');
    final b = safeName('fuckboy');
    final c = safeName('fuckboy2');
    expect(a, b);
    expect(a, isNot(c)); // разные исходники — разные псевдонимы
  });

  test('пустое имя тоже получает ник', () {
    expect(safeName('  '), isNotEmpty);
  });
}
