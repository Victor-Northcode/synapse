import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Реклама за награду — порт модуля NATIVE.
///
/// Всё «падает закрыто»: если SDK не настроен, согласия нет или ролик
/// закрыт крестиком — награда НЕ выдаётся, возвращается false.
/// Согласие (UMP) собирается ДО инициализации рекламного SDK.
class Ads {
  Ads._();
  static final Ads instance = Ads._();

  /// Официальные ТЕСТОВЫЕ блоки Google. Перед релизом подставить свои
  /// в [_realUnit]: тестовые id в проде — нарушение политики AdMob.
  static const _testUnit = {
    'android': 'ca-app-pub-3940256099942544/5224354917',
    'ios': 'ca-app-pub-3940256099942544/1712485313',
  };
  static const _realUnit = {'android': '', 'ios': ''};

  // В вебе Platform недоступен и рекламного SDK нет — реклама выключена.
  bool get hasAds => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get usingTestAds => _unit == _testUnit[_platform];

  String get _platform => Platform.isIOS ? 'ios' : 'android';
  String get _unit {
    final real = _realUnit[_platform];
    return (real != null && real.isNotEmpty) ? real : _testUnit[_platform]!;
  }

  bool _canAds = true;
  bool _privacyOptionsRequired = false;
  Future<void>? _initFuture;

  bool get needsPrivacyOptions => _privacyOptionsRequired;

  Future<void> _gatherConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
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

  /// Резолвится true ТОЛЬКО когда ролик действительно досмотрен.
  Future<bool> rewarded() async {
    if (!hasAds) return false;
    try {
      await init();
      if (!_canAds) return false;

      final ad = await _load();
      if (ad == null) return false;

      final result = Completer<bool>();
      var earned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
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

  Future<RewardedAd?> _load() {
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => completer.complete(ad),
        onAdFailedToLoad: (error) => completer.complete(null),
      ),
    );
    return completer.future;
  }
}
