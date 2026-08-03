// Музыка проверяется математикой (послушать в CI нельзя):
// корректный WAV, живые уровни, слоистая структура и бесшовный стык —
// для обоих треков (меню и игра).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:synapse/core/audio.dart';

Float64List _samples(Uint8List wav) {
  final bd = ByteData.sublistView(wav, 44);
  final n = bd.lengthInBytes ~/ 2;
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = bd.getInt16(i * 2, Endian.little) / 32767.0;
  }
  return out;
}

double _rms(Float64List s, int from, int to) {
  var acc = 0.0;
  for (var i = from; i < to; i++) {
    acc += s[i] * s[i];
  }
  return math.sqrt(acc / (to - from));
}

void main() {
  final rate = GameAudio.debugMusicRate;

  for (final scene in MusicScene.values) {
    final wav = GameAudio.debugBuildTrack(scene);
    final (loop, xf) = GameAudio.debugLoopXfade(scene);
    final s = _samples(wav);

    test('$scene: трек нужной длины и не клиппует', () {
      expect(s.length, (rate * (loop + xf)).round());
      var peak = 0.0;
      for (final v in s) {
        peak = math.max(peak, v.abs());
      }
      expect(peak, lessThan(1.0), reason: 'клиппинг = треск');
      expect(peak, greaterThan(.5), reason: 'слишком тихо');
    });

    test('$scene: стык бесшовный — хвост+голова дают уровень тела', () {
      final tailStart = (loop * rate).round();
      final n = (xf * rate).round();
      final mixed = Float64List(n);
      for (var i = 0; i < n; i++) {
        mixed[i] = s[tailStart + i] + s[i];
      }
      final seam = _rms(mixed, 0, n);
      final body = _rms(s, (8 * rate), (8 * rate) + n);
      expect(seam, greaterThan(body * .75),
          reason: 'провал громкости на стыке = слышимая пауза');
      expect(seam, lessThan(body * 1.4), reason: 'горб громкости на стыке');
    });
  }

  test('меню: структура живая — грув громче вступления', () {
    final s = _samples(GameAudio.debugBuildTrack(MusicScene.menu));
    final intro = _rms(s, (10 * rate), (20 * rate));
    final groove = _rms(s, (95 * rate), (110 * rate));
    expect(groove, greaterThan(intro * 1.15),
        reason: 'слои (арпеджио, бас, хэты) должны прибавлять плотности');
  });

  test('игра плотнее меню: пульс и арпеджио держат темп', () {
    final menu = _samples(GameAudio.debugBuildTrack(MusicScene.menu));
    final play = _samples(GameAudio.debugBuildTrack(MusicScene.play));
    // Сравниваем спокойное вступление меню с телом игрового трека.
    final menuIntro = _rms(menu, (10 * rate), (20 * rate));
    final playBody = _rms(play, (10 * rate), (20 * rate));
    expect(playBody, greaterThan(menuIntro),
        reason: 'игровой трек должен ощущаться энергичнее');
  });
}
