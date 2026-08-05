import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Плейсменты rewarded-рекламы: у каждого свой блок AdMob, чтобы в
/// консоли было видно, какое место сколько приносит.
enum AdSlot { hint, double_, continue_, shard, item, theme }

/// Реклама — порт модуля NATIVE.
///
/// Всё «падает закрыто»: если SDK не настроен, согласия нет или ролик
/// закрыт крестиком — награда НЕ выдаётся, возвращается false.
/// Согласие (UMP) собирается ДО инициализации рекламного SDK.
class Ads {
  Ads._();
  static final Ads instance = Ads._();

  /// Боевые блоки (издатель ca-app-pub-8344059151047879).
  static const _realUnit = {
    AdSlot.hint: {
      'android': 'ca-app-pub-8344059151047879/1549477233',
      'ios': 'ca-app-pub-8344059151047879/5427464336',
    },
    AdSlot.double_: {
      'android': 'ca-app-pub-8344059151047879/2097372221',
      'ios': 'ca-app-pub-8344059151047879/6373714493',
    },
    AdSlot.continue_: {
      'android': 'ca-app-pub-8344059151047879/7293858581',
      'ios': 'ca-app-pub-8344059151047879/7731742202',
    },
    AdSlot.shard: {
      'android': 'ca-app-pub-8344059151047879/5980776919',
      'ios': 'ca-app-pub-8344059151047879/1658388527',
    },
    AdSlot.item: {
      'android': 'ca-app-pub-8344059151047879/3146730018',
      'ios': 'ca-app-pub-8344059151047879/5130729673',
    },
    AdSlot.theme: {
      'android': 'ca-app-pub-8344059151047879/2354578438',
      'ios': 'ca-app-pub-8344059151047879/1971435052',
    },
  };
  static const _realInterUnit = {
    'android': 'ca-app-pub-8344059151047879/9366709346',
    'ios': 'ca-app-pub-8344059151047879/2955158324',
  };

  /// Официальные ТЕСТОВЫЕ блоки Google — для разработки.
  static const _testUnit = {
    'android': 'ca-app-pub-3940256099942544/5224354917',
    'ios': 'ca-app-pub-3940256099942544/1712485313',
  };
  static const _testInterUnit = {
    'android': 'ca-app-pub-3940256099942544/1033173712',
    'ios': 'ca-app-pub-3940256099942544/4411468910',
  };

  /// В дебаге ОБЯЗАТЕЛЬНО тестовые блоки: клики по своей боевой рекламе
  /// во время разработки — бан аккаунта AdMob.
  bool useTestAds = kDebugMode;

  // В вебе Platform недоступен и рекламного SDK нет — реклама выключена.
  bool get hasAds => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get usingTestAds => useTestAds;

  String get _platform => Platform.isIOS ? 'ios' : 'android';
  String _unit(AdSlot slot) =>
      useTestAds ? _testUnit[_platform]! : _realUnit[slot]![_platform]!;
  String get _interUnit =>
      useTestAds ? _testInterUnit[_platform]! : _realInterUnit[_platform]!;

  /// Когда игрок в последний раз ДОСМОТРЕЛ любой rewarded (x2, продолжение,
  /// подсказка, магазин). Нужна interstitial-гейту: после rewarded держим
  /// паузу, чтобы не поймать две рекламы подряд.
  DateTime? lastRewardedAt;

  bool _canAds = true;
  bool _privacyOptionsRequired = false;
  Future<void>? _initFuture;

  bool get needsPrivacyOptions => _privacyOptionsRequired;

  /// Возраст пользователя из нейтрального возрастного экрана.
  /// 0 (не указан) трактуется как ребёнок — строгий режим по умолчанию.
  int _age = 0;

  /// Применить возраст (COPPA/GDPR-K):
  /// - до 13 лет — реклама «для детей» (TFCD) и контент не выше G;
  /// - до 16 — без персонализации (TFUA, согласие не запрашивается);
  /// - взрослым — обычный режим с формой согласия UMP.
  /// Можно вызывать в любой момент — конфигурация досылается в SDK.
  Future<void> setAge(int age) async {
    _age = age;
    if (!hasAds || _initFuture == null) return;
    try {
      await _applyRequestConfig();
    } catch (_) {}
  }

  Future<void> _applyRequestConfig() {
    return MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
      tagForChildDirectedTreatment: _age < 13
          ? TagForChildDirectedTreatment.yes
          : TagForChildDirectedTreatment.no,
      tagForUnderAgeOfConsent:
          _age < 16 ? TagForUnderAgeOfConsent.yes : TagForUnderAgeOfConsent.no,
      maxAdContentRating: _age < 13
          ? MaxAdContentRating.g
          : (_age < 18 ? MaxAdContentRating.t : MaxAdContentRating.ma),
    ));
  }

  Future<void> _gatherConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: _age < 16),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((error) async {
            _canAds = await ConsentInformation.instance.canRequestAds();
            _privacyOptionsRequired =
                await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
                    PrivacyOptionsRequirementStatus.required;
            completer.complete();
          });
        } catch (_) {
          _canAds = false;
          completer.complete();
        }
      },
      (error) {
        // Нет сети или форма недоступна — рекламы не будет, игра работает.
        _canAds = false;
        completer.complete();
      },
    );
    return completer.future;
  }

  Future<void> init() {
    return _initFuture ??= () async {
      if (!hasAds) return;
      // Возрастная конфигурация — ДО сбора согласия и инициализации.
      await _applyRequestConfig();
      await _gatherConsent();
      await MobileAds.instance.initialize();
    }();
  }

  /// Открыть форму «настройки рекламы» (требование Google для ЕЭЗ).
  Future<bool> openPrivacyOptions() async {
    final completer = Completer<bool>();
    try {
      ConsentForm.showPrivacyOptionsForm((formError) async {
        _privacyOptionsRequired =
            await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
                PrivacyOptionsRequirementStatus.required;
        completer.complete(formError == null);
      });
    } catch (_) {
      return false;
    }
    return completer.future;
  }

  // ---------- предзагрузка ----------
  /// AdMob инвалидирует объявления примерно через час — старое
  /// выбрасываем и грузим заново.
  static const _adTtl = Duration(hours: 1);

  final _rewardedCache = <AdSlot, (RewardedAd, DateTime)>{};
  final _rewardedLoading = <AdSlot>{};

  /// Загрузить ролик слота в фон: тап по кнопке покажет его мгновенно.
  /// Ошибки глотаются — просто останемся без кэша и загрузим по тапу.
  void preload(AdSlot slot) {
    if (!hasAds || _rewardedLoading.contains(slot)) return;
    if (_freshRewarded(slot) != null) return;
    _rewardedLoading.add(slot);
    () async {
      try {
        await init();
        if (!_canAds) return;
        final ad = await _loadRewarded(slot);
        if (ad != null) _rewardedCache[slot] = (ad, DateTime.now());
      } catch (_) {
      } finally {
        _rewardedLoading.remove(slot);
      }
    }();
  }

  /// Свежий кэш слота; просроченный — утилизируется на месте.
  RewardedAd? _freshRewarded(AdSlot slot) {
    final c = _rewardedCache[slot];
    if (c == null) return null;
    if (DateTime.now().difference(c.$2) < _adTtl) return c.$1;
    _rewardedCache.remove(slot);
    c.$1.dispose();
    return null;
  }

  /// Резолвится true ТОЛЬКО когда ролик действительно досмотрен.
  Future<bool> rewarded(AdSlot slot) async {
    if (!hasAds) return false;
    try {
      await init();
      if (!_canAds) return false;

      var ad = _freshRewarded(slot);
      if (ad != null) _rewardedCache.remove(slot);
      ad ??= await _loadRewarded(slot);
      if (ad == null) return false;

      final result = Completer<bool>();
      var earned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          lastRewardedAt = DateTime.now();
          preload(slot); // следующий ролик — сразу в фон
          if (!result.isCompleted) result.complete(earned);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          if (!result.isCompleted) result.complete(false);
        },
      );
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      return result.future.timeout(const Duration(minutes: 3), onTimeout: () => earned);
    } catch (_) {
      return false;
    }
  }

  Future<RewardedAd?> _loadRewarded(AdSlot slot) {
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _unit(slot),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => completer.complete(ad),
        onAdFailedToLoad: (error) => completer.complete(null),
      ),
    );
    return completer.future;
  }

  // ---------- interstitial между уровнями ----------
  (InterstitialAd, DateTime)? _inter;
  bool _interLoading = false;

  /// Загрузить interstitial заранее — пока игрок проходит уровень.
  /// Показ без предзагрузки рвал бы переход на следующий уровень.
  void preloadInterstitial() {
    if (!hasAds || _interLoading) return;
    final c = _inter;
    if (c != null) {
      if (DateTime.now().difference(c.$2) < _adTtl) return;
      _inter = null;
      c.$1.dispose(); // протухший (AdMob инвалидирует через час)
    }
    _interLoading = true;
    () async {
      try {
        await init();
        if (!_canAds) {
          _interLoading = false;
          return;
        }
        InterstitialAd.load(
          adUnitId: _interUnit,
          request: const AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) {
              _inter = (ad, DateTime.now());
              _interLoading = false;
            },
            onAdFailedToLoad: (error) => _interLoading = false,
          ),
        );
      } catch (_) {
        _interLoading = false;
      }
    }();
  }

  /// Показать предзагруженный interstitial. Резолвится после закрытия,
  /// true — если реклама была показана. Если ролик не готов или протух —
  /// мгновенно false: слот пропускается, игра не ждёт (падаем закрыто,
  /// как и весь модуль).
  Future<bool> showInterstitial() async {
    final c = _inter;
    if (!hasAds || c == null) return false;
    _inter = null;
    if (DateTime.now().difference(c.$2) >= _adTtl) {
      c.$1.dispose();
      preloadInterstitial();
      return false;
    }
    try {
      final result = Completer<bool>();
      c.$1.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          preloadInterstitial(); // следующий — сразу в фон
          if (!result.isCompleted) result.complete(true);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          if (!result.isCompleted) result.complete(false);
        },
      );
      await c.$1.show();
      return result.future.timeout(const Duration(minutes: 3), onTimeout: () => true);
    } catch (_) {
      return false;
    }
  }
}
