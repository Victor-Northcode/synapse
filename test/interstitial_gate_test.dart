import 'package:flutter_test/flutter_test.dart';
import 'package:synapse/core/interstitial_gate.dart';

void main() {
  var now = DateTime(2026, 1, 1, 12);
  InterstitialGate gate() => InterstitialGate(clock: () => now);

  /// n побед подряд.
  void wins(InterstitialGate g, int n) {
    for (var i = 0; i < n; i++) {
      g.recordWin();
    }
  }

  setUp(() => now = DateTime(2026, 1, 1, 12));

  test('показ каждой третьей победы, не раньше', () {
    final g = gate();
    g.recordWin();
    expect(g.shouldShowInterstitial(win: true, level: 20), false);
    g.recordWin();
    expect(g.shouldShowInterstitial(win: true, level: 20), false);
    g.recordWin();
    expect(g.shouldShowInterstitial(win: true, level: 20), true);
  });

  test('после провала не показывается никогда', () {
    final g = gate();
    wins(g, 6);
    expect(g.shouldShowInterstitial(win: false, level: 20), false);
    expect(g.shouldShowInterstitial(win: true, level: 20), true);
  });

  test('первые уровни без рекламы: до 10-го нет, с 10-го можно', () {
    final g = gate();
    wins(g, 3);
    expect(g.shouldShowInterstitial(win: true, level: 9), false);
    expect(g.shouldShowInterstitial(win: true, level: 10), true);
  });

  test('после показа счётчик обнуляется', () {
    final g = gate();
    wins(g, 3);
    expect(g.shouldShowInterstitial(win: true, level: 20), true);
    g.markShown();
    g.recordWin();
    now = now.add(const Duration(minutes: 10));
    expect(g.shouldShowInterstitial(win: true, level: 21), false);
  });

  test('кулдаун 120с: быстрые победы после показа ждут таймер', () {
    final g = gate();
    wins(g, 3);
    g.markShown();
    wins(g, 3);
    now = now.add(const Duration(seconds: 119));
    expect(g.shouldShowInterstitial(win: true, level: 25), false);
    // Счётчик не сгорел: после таймера показ разрешается.
    now = now.add(const Duration(seconds: 2));
    expect(g.shouldShowInterstitial(win: true, level: 26), true);
  });

  test('недавний rewarded сжигает слот целиком, а не откладывает', () {
    final g = gate();
    wins(g, 3);
    final rewardedAt = now.subtract(const Duration(seconds: 30));
    expect(
        g.shouldShowInterstitial(
            win: true, level: 20, lastRewardedAt: rewardedAt),
        false);
    // Счётчик сброшен: даже когда кулдаун прошёл, нужен новый цикл побед.
    now = now.add(const Duration(minutes: 5));
    expect(
        g.shouldShowInterstitial(
            win: true, level: 21, lastRewardedAt: rewardedAt),
        false);
    wins(g, 3);
    expect(
        g.shouldShowInterstitial(
            win: true, level: 24, lastRewardedAt: rewardedAt),
        true);
  });

  test('rewarded старше 60с показу не мешает', () {
    final g = gate();
    wins(g, 3);
    expect(
        g.shouldShowInterstitial(
            win: true,
            level: 20,
            lastRewardedAt: now.subtract(const Duration(seconds: 61))),
        true);
  });

  test('кап 5 показов за сессию', () {
    final g = gate();
    for (var i = 0; i < 5; i++) {
      wins(g, 3);
      now = now.add(const Duration(minutes: 3));
      expect(g.shouldShowInterstitial(win: true, level: 20 + i), true);
      g.markShown();
    }
    wins(g, 3);
    now = now.add(const Duration(minutes: 3));
    expect(g.shouldShowInterstitial(win: true, level: 30), false);
  });

  test('предзагрузка готова по статическим условиям', () {
    final g = gate();
    expect(g.readyToPreload(20), false);
    wins(g, 3);
    expect(g.readyToPreload(20), true);
    expect(g.readyToPreload(9), false);
  });
}
