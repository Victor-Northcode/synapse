import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse/core/storage.dart';
import 'package:synapse/state/app_state.dart';
import 'package:synapse/state/play_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> makeApp() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.instance.init();
    return AppState()..loadSaved();
  }

  test('победа: награда, уровень растёт, сохранение живо', () async {
    final app = await makeApp();
    final play = PlayState(app, 360, 460)..start(1);
    expect(play.crossings, greaterThan(0));

    play.win();

    expect(play.result, isNotNull);
    expect(play.result!.win, isTrue);
    expect(app.level, 2);
    expect(app.tokens, greaterThan(0));
    expect(app.shards, greaterThan(0), reason: 'осколок за прохождение без подсказок');
    expect(app.gp[0], 1);
    play.dispose();
  });

  test('перегрузка: результат-провал и продолжение за ролик', () async {
    final app = await makeApp();
    final play = PlayState(app, 360, 460)..start(3);
    play.boom();
    expect(play.result!.win, isFalse);
    expect(app.level, 1, reason: 'уровень не растёт при провале');

    play.continueAfterAd();
    expect(play.alive, isTrue);
    expect(play.moves, greaterThanOrEqualTo(3));
    play.quit();
    play.dispose();
  });

  test('бустер «стабилизатор» добавляет ходы, подсказка подсвечивает', () async {
    final app = await makeApp();
    app.inv['stab'] = 1;
    final play = PlayState(app, 360, 460)..start(2);
    final before = play.moves;
    play.useBoost('stab');
    expect(play.moves, before + 3);
    expect(app.inv['stab'], 0);

    expect(app.hintStock, 2);
    expect(play.useHint(), isTrue);
    expect(app.hintStock, 1);
    expect(play.noHintRun, isFalse);
    play.quit();
    play.dispose();
  });

  test('задача датацентра тратит токены и двигает цель дня', () async {
    final app = await makeApp();
    app.tokens = 100;
    final cost = app.tasks[0].cost;
    app.doTask(0);
    expect(app.done[0], isTrue);
    expect(app.free, 100 - cost);
    expect(app.gp[2], 1);
  });
}
