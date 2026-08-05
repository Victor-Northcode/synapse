/// Правила показа interstitial между уровнями.
///
/// Вся настройка — здесь, в [InterstitialConfig], а не размазана по коду:
/// частоту можно крутить без правок логики. Сам гейт — чистая логика
/// без рекламного SDK (часы и метка rewarded инъецируются), поэтому
/// покрывается юнит-тестами.
library;

class InterstitialConfig {
  /// Показ каждой N-й победы. Реже — теряем деньги, чаще — ретеншен.
  final int everyNLevels;

  /// Таймерный предохранитель: не чаще одного показа в этот интервал.
  /// Работает связкой со счётчиком побед — срабатывает то условие,
  /// которое наступит позже.
  final int minSecondsBetweenAds;

  /// До этого уровня interstitial не показываем вообще: первые минуты
  /// решают D1, монетизировать их рано.
  final int firstAfterLevel;

  /// Если недавно был ЛЮБОЙ rewarded — слот пропускается целиком
  /// (не откладывается): две рекламы подряд — нарушение политики AdMob
  /// и убийство ретеншена.
  final int skipIfRewardedWithin;

  /// Кап на сессию: дальше игрок уже дал всё, что мог.
  final int maxPerSession;

  /// Только после победы: после перегрузки игрок хочет «ещё разок»,
  /// реклама там убивает петлю повтора.
  final bool onlyAfterWin;

  const InterstitialConfig({
    this.everyNLevels = 3,
    this.minSecondsBetweenAds = 120,
    this.firstAfterLevel = 10,
    this.skipIfRewardedWithin = 60,
    this.maxPerSession = 5,
    this.onlyAfterWin = true,
  });
}

class InterstitialGate {
  final InterstitialConfig config;
  final DateTime Function() _now;

  int _winsSinceShow = 0;
  int _shownThisSession = 0;
  DateTime? _lastShownAt;

  InterstitialGate({this.config = const InterstitialConfig(), DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  /// Победа засчитана (вызывается в момент выигрыша, не в момент слота):
  /// уход в хаб вместо «дальше» победу из счётчика не стирает.
  void recordWin() => _winsSinceShow++;

  /// Статические условия выполнены — пора грузить ролик, пока игрок
  /// смотрит экран результата. Кулдауны здесь не учитываются: к моменту
  /// слота они могут истечь.
  bool readyToPreload(int level) =>
      _shownThisSession < config.maxPerSession &&
      level >= config.firstAfterLevel &&
      _winsSinceShow >= config.everyNLevels;

  /// Решение в момент слота (закрытие экрана результата, переход на
  /// следующий уровень). [lastRewardedAt] — когда игрок в последний раз
  /// досмотрел rewarded. Единственный побочный эффект — rewarded-скип:
  /// он сжигает слот целиком, сбрасывая счётчик побед. Таймерный
  /// предохранитель счётчик НЕ трогает — показ ждёт следующую победу.
  bool shouldShowInterstitial({
    required bool win,
    required int level,
    DateTime? lastRewardedAt,
  }) {
    if (config.onlyAfterWin && !win) return false;
    if (!readyToPreload(level)) return false;
    final now = _now();
    if (lastRewardedAt != null &&
        now.difference(lastRewardedAt).inSeconds < config.skipIfRewardedWithin) {
      _winsSinceShow = 0;
      return false;
    }
    if (_lastShownAt != null &&
        now.difference(_lastShownAt!).inSeconds < config.minSecondsBetweenAds) {
      return false;
    }
    return true;
  }

  /// Ролик реально показан (не просто разрешён): если загрузка не успела
  /// и показа не было — счётчик сохраняется, попытка на следующей победе.
  void markShown() {
    _winsSinceShow = 0;
    _shownThisSession++;
    _lastShownAt = _now();
  }
}
