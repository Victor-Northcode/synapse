import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Синтезатор звуков игры — порт tone()/chord()/noiseBurst() из WebAudio.
/// Звук генерируется в PCM-WAV на лету и кэшируется по параметрам.
///
/// Аудио-сессия настроена «не мешать»: звуки игры МИКШИРУЮТСЯ с музыкой
/// телефона (iOS ambient + mixWithOthers, Android focus none) — плеер
/// пользователя не ставится на паузу.
class GameAudio {
  GameAudio._();
  static final GameAudio instance = GameAudio._();

  bool enabled = true;

  static const _rate = 22050;
  final Map<String, Uint8List> _cache = {};
  final List<AudioPlayer> _pool = [];
  int _next = 0;

  // ---- фоновая музыка ----
  // Гэплесс своими руками: платформенные лупы (и MediaPlayer, и SoundPool)
  // дают слышимую щель на стыке. Поэтому два плеера запускают один и тот
  // же трек по кругу с перекрытием: хвост записан с затуханием, голова —
  // с нарастанием, в перекрытии контент идентичен и суммируется в единицу.
  // Трек длинный (2 м 40 с, живая структура), а кроссфейд широкий (6 с):
  // даже секундная задержка старта второго плеера растворяется в нём.
  static const _musicLoop = 160.0; // период запуска следующего круга, с
  static const _musicXfade = 6.0; // перекрытие, с
  final List<AudioPlayer> _musicPair = [];
  int _musicNext = 0;
  Timer? _musicTimer;
  Uint8List? _musicWav;
  bool _musicOn = false;

  /// init() завершён — аудио-плагин доступен, музыку можно запускать.
  /// До этого желание «музыка включена» просто запоминается: в тестах
  /// init() не зовут, и плагин не трогается вовсе.
  bool _ready = false;

  Future<void> init() async {
    try {
      AudioLogger.logLevel = AudioLogLevel.none;
      // Глобальная аудио-сессия: не отбирать фокус у музыки телефона.
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ));
    } catch (_) {
      // Среда без нативной аудио-сессии (веб, тесты) — просто продолжаем.
    }
    try {
      for (var i = 0; i < 6; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        _pool.add(p);
      }
    } catch (_) {
      _pool.clear(); // среда без аудио — игра работает молча
    }
    _ready = true;
    if (_musicOn) await _startMusic();
  }

  Future<void> _play(Uint8List wav) async {
    if (_pool.isEmpty) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await p.stop();
      await p.play(BytesSource(wav, mimeType: 'audio/wav'));
    } catch (_) {}
  }

  // ---------- фоновая музыка ----------
  /// Очень лёгкий эмбиент: два аккорда-пэда перетекают друг в друга,
  /// поверх — редкие тихие «колокольчики». Петля бесшовная (все частоты
  /// кратны длине петли), генерируется один раз и крутится в цикле.
  Future<void> setMusicEnabled(bool on) async {
    _musicOn = on;
    if (!_ready) return; // применится, когда init() поднимет плагин
    if (!on) {
      await _stopMusic();
      return;
    }
    await _startMusic();
  }

  Future<void> _startMusic() async {
    try {
      if (_musicPair.isEmpty) {
        for (var i = 0; i < 2; i++) {
          final p = AudioPlayer();
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setVolume(.5);
          _musicPair.add(p);
        }
      }
      // Синтез трека тяжёлый (~2.7 млн сэмплов) — уводим в изолят,
      // чтобы интерфейс не дёргался; без изолята (веб) считаем на месте.
      if (_musicWav == null) {
        try {
          _musicWav = await Isolate.run(_buildMusic);
        } catch (_) {
          _musicWav = _buildMusic();
        }
      }
      if (!_musicOn) return; // выключили, пока считался трек
      _musicTimer?.cancel();
      await _musicPair[0].stop();
      await _musicPair[1].stop();
      await _musicPair[0].play(BytesSource(_musicWav!, mimeType: 'audio/wav'));
      _musicNext = 1;
      // Каждые _musicLoop секунд стартует второй плеер: хвост текущего
      // круга и голова следующего перекрываются на _musicXfade секунд.
      _musicTimer = Timer.periodic(
          Duration(milliseconds: (_musicLoop * 1000).round()), (_) async {
        final p = _musicPair[_musicNext];
        _musicNext = 1 - _musicNext;
        try {
          await p.stop();
          await p.play(BytesSource(_musicWav!, mimeType: 'audio/wav'));
        } catch (_) {}
      });
    } catch (_) {
      // Без аудио-движка музыки просто нет.
    }
  }

  Future<void> _stopMusic() async {
    _musicTimer?.cancel();
    _musicTimer = null;
    for (final p in _musicPair) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  /// Пауза/возврат музыки вместе с приложением: игра не должна звучать
  /// из фона. Возврат перезапускает петлю с начала — так фазы двух
  /// плееров гарантированно сходятся.
  Future<void> onAppPaused() async {
    if (_musicOn) await _stopMusic();
  }

  Future<void> onAppResumed() async {
    if (_musicOn && _ready) await _startMusic();
  }

  /// Осциллятор с экспоненциальным затуханием, как в WebAudio-версии.
  void tone(double freq, [double dur = .12, String type = 'square', double vol = .05]) {
    if (!enabled) return;
    final key = 't$freq|$dur|$type|$vol';
    final wav = _cache.putIfAbsent(key, () => _synthTone(freq, dur, type, vol));
    _play(wav);
  }

  /// Арпеджио синусов с шагом 70 мс.
  void chord(List<double> freqs, [double dur = .22]) {
    if (!enabled) return;
    for (var i = 0; i < freqs.length; i++) {
      Future.delayed(Duration(milliseconds: i * 70), () {
        tone(freqs[i], dur, 'sine', .05);
      });
    }
  }

  /// Шумовой всплеск взрыва: белый шум через полосовой фильтр 800 Гц.
  void noiseBurst() {
    if (!enabled) return;
    final wav = _cache.putIfAbsent('noise', _synthNoise);
    _play(wav);
  }

  /// Тон защёлкивания. Высота привязана к ПРОГРЕССУ уровня и идёт
  /// строго на понижение: чем меньше пересечений осталось, тем ниже
  /// и спокойнее нота. Никаких скачков «с начала» — шкала монотонная.
  /// [progress] — доля распутанного (0 — начало, 1 — почти готово).
  void snapTone(int seq, [double progress = 0]) {
    const pent = [0, 2, 4, 7, 9];
    const steps = 10;
    final p = progress.clamp(0.0, 1.0);
    final idx = ((1 - p) * (steps - 1)).round();
    final oct = idx ~/ pent.length;
    final f0 =
        294 * math.pow(2, (pent[idx % pent.length] + 12 * oct) / 12).toDouble();
    tone(f0, .10, 'triangle', .055);
    tone(f0 * 1.5, .07, 'sine', .018 + oct * 0.006);
  }

  Uint8List _synthTone(double freq, double dur, String type, double vol) {
    final n = (_rate * (dur + .02)).round();
    final data = Float64List(n);
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final ph = (t * freq) % 1.0;
      double s;
      switch (type) {
        case 'sine':
          s = math.sin(2 * math.pi * ph);
        case 'sawtooth':
          s = 2 * ph - 1;
        case 'triangle':
          s = ph < .5 ? 4 * ph - 1 : 3 - 4 * ph;
        default: // square
          s = ph < .5 ? 1 : -1;
      }
      // gain.exponentialRampToValueAtTime(.0008, t+dur)
      final k = math.min(1.0, t / .003); // короткая атака против щелчка
      final env = vol * math.pow(.0008 / vol, math.min(1.0, t / dur));
      data[i] = s * env * k;
    }
    return _wav(data);
  }

  Uint8List _synthNoise() {
    final n = (_rate * 0.35).round();
    final rnd = math.Random();
    final data = Float64List(n);
    // Полосовой биквад-фильтр 800 Гц, Q 0.7 (как BiquadFilter в исходнике).
    const f = 800.0, q = 0.7;
    final w0 = 2 * math.pi * f / _rate;
    final alpha = math.sin(w0) / (2 * q);
    final b0 = alpha, b1 = 0.0, b2 = -alpha;
    final a0 = 1 + alpha, a1 = -2 * math.cos(w0), a2 = 1 - alpha;
    double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (var i = 0; i < n; i++) {
      final x0 = (rnd.nextDouble() * 2 - 1) * math.pow(1 - i / n, 2.2);
      final y0 = (b0 / a0) * x0 + (b1 / a0) * x1 + (b2 / a0) * x2 - (a1 / a0) * y1 - (a2 / a0) * y2;
      x2 = x1; x1 = x0; y2 = y1; y1 = y0;
      data[i] = y0 * 0.12 * 4; // компенсация ослабления фильтра
    }
    return _wav(data);
  }

  /// Частота музыки 16 кГц: пэду и плюкам выше 8 кГц ничего не нужно,
  /// а буфер остаётся скромным.
  static const _musicRate = 16000;

  /// Для тестов: собранный трек и его параметры.
  static Uint8List debugBuildMusic() => _buildMusic();
  static int get debugMusicRate => _musicRate;
  static double get debugMusicLoop => _musicLoop;
  static double get debugMusicXfade => _musicXfade;

  /// Трек 160 секунд с живой структурой (статический — считается в
  /// изоляте). Аккорды Am → F → C → G крутятся по 5 секунд весь трек,
  /// а слои приходят и уходят, как в настоящем эмбиент-электро:
  ///   0–40   пэд и редкие колокольчики — спокойное вступление
  ///   40–80  + арпеджио-перебор с эхом
  ///   80–120 + пульс суб-баса и тихие хэты — грув
  ///   120–140 всё вместе — кульминация
  ///   140–160 слои гаснут, остаётся пэд — петля замыкается в тишину
  ///   вступления, поэтому повтор через 2 м 40 с не ощущается повтором.
  /// Хвост файла (6 с) повторяет голову с линейным затуханием — при
  /// наложении двух плееров стык суммируется в единицу.
  static Uint8List _buildMusic() {
    const loop = _musicLoop;
    const xf = _musicXfade;
    final n = (_musicRate * (loop + xf)).round();
    final data = Float64List(n);

    // Частота подгоняется к целому числу циклов на 20-секундный такт.
    double snap(double f) => (f * 20).roundToDouble() / 20;

    final chords = [
      [110.0, 164.81, 220.0, 261.63, 329.63], // Am
      [87.31, 174.61, 220.0, 261.63, 349.23], // F
      [130.81, 196.0, 261.63, 329.63, 392.0], // C
      [98.0, 146.83, 246.94, 293.66, 392.0], // G
    ].map((c) => c.map(snap).toList()).toList();
    const padAmps = [.4, .22, .2, .17, .1];

    const bells = [
      (1.4, 659.25), (3.2, 880.0), (6.1, 587.33), (8.4, 523.25),
      (11.2, 783.99), (13.6, 659.25), (16.1, 987.77), (18.2, 880.0),
    ];

    // Арпеджио: восьмые (0.25 с), рисунок по тонам текущего аккорда.
    const arpPattern = [0, 2, 4, 3, 2, 4, 2, 1, 0, 2, 4, 3, 4, 2, 3, 1];

    // Плавный вход/выход слоя.
    double ramp(double t, double a, double b) =>
        ((t - a) / (b - a)).clamp(0.0, 1.0);

    // Пэд + колокольчики — базовый слой, периодичен по 20 с.
    double pad(double tm) {
      final ct = tm % 20;
      final x = ct / 5; // позиция в прогрессии, 0..4
      var s = 0.0;
      for (var ci = 0; ci < 4; ci++) {
        var d = (x - ci).abs();
        if (d > 2) d = 4 - d;
        if (d >= 1) continue;
        final w = math.pow(math.cos(d * math.pi / 2), 2).toDouble();
        for (var k = 0; k < 5; k++) {
          final lfo = .8 + .2 * math.sin(2 * math.pi * (k + 1) * ct / 20 + ci);
          s += math.sin(2 * math.pi * chords[ci][k] * ct) * padAmps[k] * w * lfo;
        }
      }
      return s;
    }

    double bell(double tm) {
      final ct = tm % 20;
      var s = 0.0;
      for (final (at, f) in bells) {
        final j = ct - at;
        if (j < 0 || j > 1.8) continue;
        final env = math.pow(math.e, -j * 2.8) * math.min(1.0, j / .012);
        s += (math.sin(2 * math.pi * f * j) +
                .35 * math.sin(2 * math.pi * f * 2 * j)) *
            .25 *
            env;
      }
      return s;
    }

    // Аккорд, действующий в момент времени t (по началу такта ноты).
    List<double> chordAt(double t) => chords[((t % 20) / 5).floor() % 4];

    // Одна нота арпеджио, начавшаяся на границе восьмой.
    double arpNote(double tm) {
      final step = (tm / .25).floor();
      final tau = tm - step * .25;
      final ch = chordAt(step * .25);
      final f = ch[arpPattern[step % arpPattern.length] % ch.length] * 2;
      final env = math.pow(math.e, -tau * 7) * math.min(1.0, tau / .006);
      return (math.sin(2 * math.pi * f * tau) +
              .3 * math.sin(2 * math.pi * f * 2 * tau)) *
          env;
    }

    double sub(double tm) {
      final beat = (tm / .5).floor();
      final tau = tm - beat * .5;
      final f = chordAt(beat * .5)[0] / 2;
      return math.sin(2 * math.pi * f * tau) * math.pow(math.e, -tau * 5);
    }

    double hat(double tm, int i) {
      final tau = (tm + .25) % .5; // офф-бит
      if (tau > .06) return 0;
      // Детерминированный «шум» без Random — от номера сэмпла.
      final r = (math.sin(i * 12.9898) * 43758.5453);
      final noise = (r - r.floorToDouble()) * 2 - 1;
      return noise * math.pow(math.e, -tau * 90);
    }

    double sample(double tm, int i) {
      // Кривые слоёв: на краях петли все дополнительные слои в нуле,
      // поэтому хвост == голове и повтор незаметен.
      final arpG = ramp(tm, 38, 44) - ramp(tm, 142, 152);
      final subG = ramp(tm, 78, 84) - ramp(tm, 136, 146);
      final hatG = ramp(tm, 82, 88) - ramp(tm, 118, 128);
      final bellG = 1 - .6 * (ramp(tm, 44, 50) - ramp(tm, 116, 124));

      var s = pad(tm) + bell(tm) * bellG;
      if (arpG > 0) {
        // Эхо на 3/8 позади придаёт перебору глубину.
        s += (arpNote(tm) + .4 * arpNote(math.max(0, tm - .375))) * .22 * arpG;
      }
      if (subG > 0) s += sub(tm) * .5 * subG;
      if (hatG > 0) s += hat(tm, i) * .07 * hatG;
      return s;
    }

    for (var i = 0; i < n; i++) {
      final t = i / _musicRate;
      // Линейные края: нарастание в голове, затухание в хвосте.
      final env = t < xf
          ? t / xf
          : (t > loop ? (1 - (t - loop) / xf).clamp(0.0, 1.0) : 1.0);
      data[i] = sample(t % loop, i) * env;
    }

    // Нормализация: пик к 0.82 — громко, но без клиппинга и треска.
    var peak = 0.0;
    for (final v in data) {
      peak = math.max(peak, v.abs());
    }
    if (peak > 0) {
      final k = .82 / peak;
      for (var i = 0; i < n; i++) {
        data[i] *= k;
      }
    }
    return _wav(data, rate: _musicRate);
  }

  static Uint8List _wav(Float64List samples, {int rate = _rate}) {
    final n = samples.length;
    final bytes = Uint8List(44 + n * 2);
    final bd = ByteData.view(bytes.buffer);
    void str(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes[off + i] = s.codeUnitAt(i);
      }
    }
    str(0, 'RIFF');
    bd.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, 1, Endian.little);
    bd.setUint32(24, rate, Endian.little);
    bd.setUint32(28, rate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    str(36, 'data');
    bd.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      bd.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    return bytes;
  }
}
