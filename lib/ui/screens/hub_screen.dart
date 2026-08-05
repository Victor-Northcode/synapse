import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../data/game_data.dart';
import '../../data/upgrade_data.dart';
import '../../game/level.dart';
import '../../state/app_state.dart';
import '../layout.dart';
import '../widgets/common.dart';

/// Вкладка хаба, выбранная в нижнем меню.
enum HubPane { journal, supply }

/// Хаб: «журнал» (карточка модели, связь, цели дня, задачи датацентра)
/// и «склад» (бустеры, мастерская, темы).
class HubScreen extends StatelessWidget {
  final HubPane pane;
  final VoidCallback? onPlay;
  const HubScreen({super.key, required this.pane, this.onPlay});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = Layout.of(context);

    if (pane == HubPane.journal) {
      final left = <Widget>[
        StaggerIn(index: 0, child: _HubCard(app: app)),
        const SizedBox(height: 16),
        ..._playBlock(app),
      ];
      final right = <Widget>[
        StaggerIn(index: 2, child: _GoalsPanel(app: app)),
        const SizedBox(height: 12),
        StaggerIn(index: 3, child: _tasksPanel(app)),
      ];

      // Альбом на планшете: слева карточка модели и кнопка связи,
      // справа — цели и задачи со своей прокруткой.
      if (l.twoColumn) {
        Widget col(List<Widget> children) => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: children),
              ),
            );
        return Padding(
          padding: EdgeInsets.fromLTRB(l.gutter, 4, l.gutter, l.gutter),
          child: Row(children: [
            Expanded(flex: 5, child: col(left)),
            SizedBox(width: l.gutter),
            Expanded(flex: 6, child: col(right)),
          ]),
        );
      }

      return ContentColumn(
        child: ListView(
          padding: EdgeInsets.fromLTRB(l.gutter, 8, l.gutter, 24),
          children: [...left, const SizedBox(height: 16), ...right],
        ),
      );
    }

    // ---- склад ----
    final supply = <Widget>[
      StaggerIn(index: 0, child: _shopPanel(app)),
      const SizedBox(height: 12),
      StaggerIn(index: 1, child: _convertPanel(app)),
      const SizedBox(height: 12),
      StaggerIn(index: 2, child: _WorkshopPanel(app: app)),
      const SizedBox(height: 12),
      StaggerIn(index: 3, child: _themesPanel(app)),
    ];
    return ContentColumn(
      child: ListView(
        padding: EdgeInsets.fromLTRB(l.gutter, 8, l.gutter, 24),
        children: supply,
      ),
    );
  }

  // ---------- журнал: связь и задачи ----------
  List<Widget> _playBlock(AppState app) {
    final pk = lvlKind(app.level);
    final btnColor = pk == 2 ? Pal.superRed : (pk == 1 ? Pal.hardTeal : Pal.mag);
    final btnText = pk == 2
        ? const Color(0xFF2A0D0A)
        : (pk == 1 ? const Color(0xFF0C2320) : const Color(0xFF1A0512));
    return [
      StaggerIn(
        index: 1,
        child: PillButton(
          onTap: onPlay,
          pulse: true,
          color: btnColor,
          textColor: btnText,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(app.t('play').replaceAll('{n}', '${app.level}'),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (pk != 0)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  pk == 2 ? app.t('kSuper') : (pk == 1 ? app.t('kHard') : app.t('kEasy')),
                  style: TextStyle(
                      fontFamily: Fonts.mono,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: btnText.withValues(alpha: .65)),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 11),
      IconText(app.nextGoalLine(),
          style: const TextStyle(
              fontFamily: Fonts.mono, fontSize: 11.5, height: 1.45, color: Pal.yellow)),
    ];
  }

  Widget _tasksPanel(AppState app) {
    return GamePanel(
      child: Column(children: [
        Text(
          app.curDay < app.days
              ? '${app.t('dc')} · ${app.t('day').replaceAll('{n}', '${app.curDay + 1}')} — ${app.dayNames[app.curDay]}'
              : app.t('dc'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: Fonts.disp,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: .6,
              color: Pal.text),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < app.tasks.length; i++)
          if (app.tasks[i].day == app.curDay) _TaskRow(app: app, index: i),
        const SizedBox(height: 11),
        Text(app.t('dcHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: Fonts.mono, fontSize: 10, height: 1.4, color: Pal.dim)),
      ]),
    );
  }

  // ---------- склад: бустеры ----------
  Widget _shopPanel(AppState app) {
    // Карточки по две в строке; IntrinsicHeight + stretch выравнивает
    // высоту пары, описания видны целиком — без обрезаний.
    Widget pair(Widget a, Widget b) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: a),
            const SizedBox(width: 8),
            Expanded(child: b),
          ]),
        );
    return GamePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(app.t('shopT').replaceAll('{n}', '${app.shards}')),
        const SizedBox(height: 10),
        pair(_shopBooster(app, 0), _shopBooster(app, 1)),
        const SizedBox(height: 8),
        pair(_shopBooster(app, 2), _shopHint(app)),
        if (app.canAdShard) ...[
          const SizedBox(height: 12),
          Pressable(
            onTap: app.watchAdForShards,
            child: Container(
              constraints: const BoxConstraints(minHeight: 62),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0x17FFD400),
                border: Border.all(color: const Color(0x61FFD400)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconText(
                app.t('adShard').replaceAll('{n}', '${3 - app.adShards}'),
                style: const TextStyle(
                    fontFamily: Fonts.disp,
                    fontSize: 12,
                    letterSpacing: 1.8,
                    color: Pal.yellow),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  /// Обмен избытка энергии на осколки: 40{bolt} → 1✦, до 2 в день.
  Widget _convertPanel(AppState app) {
    final left = AppState.convLimit - app.convUsed;
    final can = app.canConvert;
    return GamePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(app.lt('cvT')),
        const SizedBox(height: 6),
        Text(app.lt('cvD'),
            style: const TextStyle(
                fontFamily: Fonts.mono, fontSize: 9.5, height: 1.4, color: Pal.dim)),
        const SizedBox(height: 10),
        Pressable(
          onTap: left > 0 ? app.convertEnergy : null,
          child: Opacity(
            opacity: left > 0 ? (can ? 1 : .6) : .4,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: can ? const Color(0x1500E5FF) : Colors.transparent,
                border: Border.all(
                    color: can ? const Color(0x7300E5FF) : Pal.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconText(
                left > 0
                    ? app
                        .lt('cvBtn')
                        .replaceAll('{n}', '${AppState.convCost}')
                        .replaceAll('{k}', '$left')
                    : app.lt('cvOut'),
                style: TextStyle(
                    fontFamily: Fonts.disp,
                    fontSize: 11.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: can ? Pal.cyan : Pal.dim),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _themesPanel(AppState app) {
    return GamePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(app.t('themesT')),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          childAspectRatio: 1.9,
          children: [for (var ti = 0; ti < kThemes.length; ti++) _themeCard(app, ti)],
        ),
      ]),
    );
  }

  /// Кнопка-пилюля с ценой в осколках.
  Widget _pricePill(String price, {required bool can}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: can ? const Color(0x1500E5FF) : Colors.transparent,
        border: Border.all(color: can ? const Color(0x7300E5FF) : Pal.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: IconText(price,
          style: const TextStyle(
              fontFamily: Fonts.disp,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Pal.cyan)),
    );
  }

  /// Карточка товара: иконка и запас сверху, полное название и полное
  /// описание (ничего не обрезается), внизу — покупка.
  /// Обычно это одна кнопка с ценой. Когда осколков не хватает и остался
  /// часовой лимит роликов — ДВЕ компактные кнопки рядом: цена и ролик.
  /// Без длинных слов: только цифры и значки.
  Widget _shopCard({
    required bool can,
    required VoidCallback onTap,
    required String count,
    required Widget icon,
    required String name,
    required String desc,
    required String price,
    int adLeft = 0,
    VoidCallback? onAdTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0x0D78A0FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: can ? const Color(0x3300E5FF) : Pal.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x12121A2E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Pal.line),
              ),
              child: Opacity(opacity: can || onAdTap != null ? 1 : .55, child: icon),
            ),
            const Spacer(),
            // Запас в инвентаре.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x1200E5FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('×$count',
                  style: const TextStyle(
                      fontFamily: Fonts.disp,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: Pal.cyan)),
            ),
          ]),
          const SizedBox(height: 9),
          Text(name,
              style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Pal.text)),
          const SizedBox(height: 4),
          Text(desc,
              style: const TextStyle(
                  fontFamily: Fonts.mono, fontSize: 9.5, height: 1.45, color: Pal.bodyDim)),
          const SizedBox(height: 10),
          const Spacer(),
          if (onAdTap == null)
            // Цель всегда на виду: цена показана даже когда не хватает —
            // так есть ради чего копить.
            Opacity(opacity: can ? 1 : .5, child: _pricePill(price, can: can))
          else
            // Две маленькие кнопки: слева цена (тап объяснит, сколько не
            // хватает), справа ролик со счётчиком остатка «×N».
            Row(children: [
              Expanded(
                child: Pressable(
                  onTap: onTap,
                  child: Opacity(
                      opacity: .5, child: _pricePill(price, can: false)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Pressable(
                  onTap: onAdTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x1CFFD400),
                      border: Border.all(color: const Color(0x66FFD400)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const GameIcon('tv', size: 13, color: Pal.yellow),
                      const SizedBox(width: 5),
                      Text('×$adLeft',
                          style: const TextStyle(
                              fontFamily: Fonts.disp,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: Pal.yellow)),
                    ]),
                  ),
                ),
              ),
            ]),
        ]),
      ),
    );
  }

  Widget _shopBooster(AppState app, int bi) {
    final b = kBoosters[bi];
    final can = app.shards >= b.cost;
    return _shopCard(
      can: can,
      onTap: () => app.buyBooster(bi),
      count: '${app.inv[b.key]}',
      icon: GameIcon(b.icon, size: 19, color: Pal.text),
      name: app.tl('bn')[bi],
      desc: app.tl('bd')[bi],
      price: '${b.cost}✦',
      adLeft: app.adItemsLeft,
      onAdTap: !can && app.canAdItem ? () => app.watchAdForItem(b.key) : null,
    );
  }

  Widget _shopHint(AppState app) {
    final can = app.shards >= app.hintPrice();
    return _shopCard(
      can: can,
      onTap: app.buyHint,
      count: '${app.hintStock}',
      icon: const GameIcon('bulb', size: 19, color: Pal.text),
      name: app.t('hintBuy'),
      desc: app.t('hintBuyD'),
      price: '${app.hintPrice()}✦',
      adLeft: app.adItemsLeft,
      onAdTap: !can && app.canAdItem ? () => app.watchAdForItem('hint') : null,
    );
  }

  /// Кнопка «примерить за ролик»: сутки в теме бесплатно. Витрина —
  /// игрок привыкает, потом легче отдаёт осколки. Без слов: значок
  /// ролика + «24H», понятно на всех языках.
  Widget _trialPill(AppState app, int ti) {
    return Pressable(
      onTap: () => app.watchAdForThemeTrial(ti),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x1CFFD400),
          border: Border.all(color: const Color(0x66FFD400)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          GameIcon('tv', size: 10, color: Pal.yellow),
          SizedBox(width: 3),
          Text('24H',
              style: TextStyle(
                  fontFamily: Fonts.disp,
                  fontWeight: FontWeight.w700,
                  fontSize: 8.5,
                  color: Pal.yellow)),
        ]),
      ),
    );
  }

  Widget _themeCard(AppState app, int ti) {
    final th = kThemes[ti];
    final own = app.owned[ti] == 1;
    final trial = app.themeTrialActive(ti);
    final cur = app.theme == ti;
    return Pressable(
      onTap: () => app.selectTheme(ti),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0x0D78A0FF),
          borderRadius: BorderRadius.circular(18),
          border: cur ? Border.all(color: const Color(0x8000E676)) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Превью тянется по высоте ячейки — фикс-высота ломала узкие экраны.
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [th.mag, th.cyan, th.green],
                  stops: const [0, .55, 1],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(
              child: Text(app.lang == 'ru' ? th.nameRu : th.nameEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: Fonts.mono, fontSize: 10.5, color: Pal.text)),
            ),
            if ((own || trial) && cur)
              const Glyph(GlyphKind.check, size: 15, color: Pal.green)
            else if (trial)
              // Активная примерка: остаток часов, тап применяет бесплатно.
              Text('${app.trialHoursLeft(ti)}h',
                  style: const TextStyle(
                      fontFamily: Fonts.disp,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Pal.cyan))
            else if (own)
              IconText(app.t('thUse'),
                  style: const TextStyle(
                      fontFamily: Fonts.disp,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Pal.cyan))
            else
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconText('${th.cost}✦',
                    style: const TextStyle(
                        fontFamily: Fonts.disp,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Pal.cyan)),
                if (app.canThemeTrial) ...[
                  const SizedBox(width: 6),
                  _trialPill(app, ti),
                ],
              ]),
          ]),
        ]),
      ),
    );
  }
}

/// Цели дня: три полоски прогресса и серия. Раньше цели жили только в
/// коде — игрок их не видел; теперь мотивация на виду.
class _GoalsPanel extends StatelessWidget {
  final AppState app;
  const _GoalsPanel({required this.app});

  @override
  Widget build(BuildContext context) {
    final names = app.tl('gn');
    return GamePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: SectionTitle(app.t('goalsT'))),
          if (app.streak > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x1FFF2ED1),
                border: Border.all(color: const Color(0x66FF2ED1)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                app.t('streakN').replaceAll('{d}', '${app.streak}'),
                style: const TextStyle(
                    fontFamily: Fonts.mono,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Pal.mag),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        for (var i = 0; i < 3; i++)
          _goalRow(
            name: names.length > i ? names[i] : '',
            done: app.gDone[i],
            progress: app.gp[i],
            target: kGoals[i],
            reward: 1,
          ),
        // Цели недели: крупнее и жирнее наградой, сбрасываются по
        // понедельникам.
        const SizedBox(height: 4),
        SectionTitle(app.lt('wkT')),
        const SizedBox(height: 10),
        for (var i = 0; i < 3; i++)
          _goalRow(
            name: app.lt('wk$i'),
            done: app.wgDone[i],
            progress: app.wgp[i],
            target: kWeekGoals[i],
            reward: kWeekRewards[i],
            accent: Pal.yellow,
          ),
      ]),
    );
  }

  Widget _goalRow({
    required String name,
    required bool done,
    required int progress,
    required int target,
    required int reward,
    Color accent = Pal.cyan,
  }) {
    final k = (progress / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 20,
          child: done
              ? const Glyph(GlyphKind.check, size: 14, color: Pal.green)
              : Text('$progress',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: Fonts.mono, fontSize: 9, color: Pal.dim)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: Fonts.mono,
                    fontSize: 10.5,
                    color: done ? Pal.green : Pal.text)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: done ? 1 : k),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    backgroundColor: Pal.bg,
                    valueColor: AlwaysStoppedAnimation(
                        done ? Pal.green : accent),
                  ),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 9),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('+$reward',
              style: TextStyle(
                  fontFamily: Fonts.disp,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: done ? Pal.faint : accent)),
          const SizedBox(width: 2),
          ShardIcon(size: 8, color: done ? Pal.faint : accent),
        ]),
      ]),
    );
  }
}

/// Мастерская: постоянные улучшения — главный сток осколков.
class _WorkshopPanel extends StatelessWidget {
  final AppState app;
  const _WorkshopPanel({required this.app});

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(app.lt('upT')),
        const SizedBox(height: 4),
        Text(app.lt('upHint'),
            style: const TextStyle(
                fontFamily: Fonts.mono, fontSize: 9, height: 1.4, color: Pal.dim)),
        const SizedBox(height: 10),
        for (final u in kUpgrades) _upgradeRow(u),
      ]),
    );
  }

  Widget _upgradeRow(Upgrade u) {
    final lvl = app.upLevel(u.key);
    final price = app.upPrice(u);
    final maxed = price == null;
    final can = !maxed && app.shards >= price;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: Pal.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: maxed
                  ? const Color(0x4D00E676)
                  : (can ? const Color(0x8000E5FF) : Pal.line)),
          boxShadow: can
              ? const [BoxShadow(color: Color(0x2400E5FF), blurRadius: 12)]
              : null,
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x0D78A0FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: GameIcon(u.icon,
                size: 17, color: maxed ? Pal.green : Pal.text),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(app.lt('up_${u.key}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: Fonts.mono,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Pal.text)),
                ),
                const SizedBox(width: 7),
                // Точки-уровни: сколько куплено из максимума.
                for (var d = 0; d < u.maxLevel; d++)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsetsDirectional.only(end: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d < lvl ? Pal.green : Pal.dotOff,
                    ),
                  ),
              ]),
              const SizedBox(height: 3),
              IconText(app.lt('up_${u.key}_d'),
                  align: TextAlign.start,
                  style: const TextStyle(
                      fontFamily: Fonts.mono, fontSize: 9, height: 1.3, color: Pal.faint)),
            ]),
          ),
          const SizedBox(width: 10),
          maxed
              ? Text(app.lt('upMax'),
                  style: const TextStyle(
                      fontFamily: Fonts.disp,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: Pal.green))
              : Pressable(
                  onTap: () => app.buyUpgrade(u),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: can ? const Color(0x1A00E5FF) : Colors.transparent,
                      border: Border.all(
                          color: can ? const Color(0x8000E5FF) : Pal.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('$price',
                          style: TextStyle(
                              fontFamily: Fonts.disp,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: can ? Pal.cyan : Pal.dim)),
                      const SizedBox(width: 3),
                      ShardIcon(size: 9, color: can ? Pal.cyan : Pal.dim),
                    ]),
                  ),
                ),
        ]),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final AppState app;
  const _HubCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final pct = app.donePct;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        gradient: Pal.hubCardGradient,
        border: Border.all(color: Pal.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: [
        Text('OBEN AI ${app.modelName(app.chapter)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: Fonts.disp,
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: 1.3,
              color: Pal.text,
              shadows: [Shadow(color: Color(0x59FFD400), blurRadius: 18, offset: Offset(0, 2))],
            )),
        const SizedBox(height: 5),
        Text(app.t('state'),
            style: const TextStyle(fontFamily: Fonts.mono, fontSize: 9, color: Pal.dim)),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          tween: Tween(end: pct.toDouble()),
          duration: const Duration(milliseconds: 900),
          builder: (context, v, _) => Text('${v.round()}%',
              style: const TextStyle(
                  fontFamily: Fonts.disp,
                  fontWeight: FontWeight.w900,
                  fontSize: 42,
                  height: 1,
                  color: Pal.green)),
        ),
        const SizedBox(height: 10),
        Container(
          height: 9,
          decoration: BoxDecoration(
            color: Pal.bg,
            border: Border.all(color: Pal.line),
            borderRadius: BorderRadius.circular(5),
          ),
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: pct / 100,
            child: Container(
              decoration: const BoxDecoration(
                color: Pal.green,
                boxShadow: [BoxShadow(color: Color(0x8000E676), blurRadius: 10)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '${app.t('sub')} '),
            TextSpan(
                text: '${app.done.where((x) => x).length}/${app.tasks.length}',
                style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700)),
          ]),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: Fonts.mono, fontSize: 10, letterSpacing: .6, color: Pal.dim),
        ),
      ]),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final AppState app;
  final int index;
  const _TaskRow({required this.app, required this.index});

  @override
  Widget build(BuildContext context) {
    final t = app.tasks[index];
    final isDone = app.done[index];
    final can = !isDone && app.free >= t.cost;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: can ? () => app.doTask(index) : null,
        child: Opacity(
          opacity: isDone ? .75 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Pal.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isDone ? Pal.green : (can ? Pal.yellow : Pal.line)),
              boxShadow: can
                  ? const [BoxShadow(color: Color(0x40FFD400), blurRadius: 10)]
                  : null,
            ),
            child: Row(children: [
              GameIcon(t.icon,
                  size: 22, color: isDone ? Pal.green : (can ? Pal.text : Pal.dim)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.taskNames[index],
                      style: const TextStyle(
                          fontFamily: Fonts.mono, fontSize: 12, color: Pal.text)),
                  if (t.fx != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(t.fx == 't' ? app.t('fxT') : app.t('fxH'),
                          style: const TextStyle(
                              fontFamily: Fonts.mono, fontSize: 9, color: Pal.dim)),
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              // Что делать с задачей — видно сразу: активная превращается
              // в явную кнопку «Построить · N⚡», недоступная — тусклая цена.
              if (isDone)
                const Glyph(GlyphKind.check, size: 16, color: Pal.green)
              else if (can)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0x24FFD400),
                    border: Border.all(color: const Color(0x8CFFD400)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(app.lt('bld'),
                        style: const TextStyle(
                            fontFamily: Fonts.mono,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                            color: Pal.yellow)),
                    const SizedBox(width: 5),
                    Text('${t.cost}',
                        style: const TextStyle(
                            fontFamily: Fonts.disp,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: Pal.yellow)),
                    const GameIcon('bolt', size: 11, solid: true, color: Pal.yellow),
                  ]),
                )
              else
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${t.cost}',
                      style: const TextStyle(
                          fontFamily: Fonts.disp,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Pal.dim)),
                  const SizedBox(width: 2),
                  const GameIcon('bolt', size: 12, solid: true, color: Pal.dim),
                ]),
            ]),
          ),
        ),
      ),
    );
  }
}
