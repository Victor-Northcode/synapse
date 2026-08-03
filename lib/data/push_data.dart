/// Тексты ежедневных напоминаний — по несколько вариантов заголовков и
/// тел, чтобы уведомления не повторялись день за днём.
/// Первый день использует контекстные строки nudge* из основного словаря,
/// дальше идёт ротация этих.
const Map<String, ({List<String> titles, List<String> bodies})> kPushStrings = {
  'en': (
    titles: [
      'SYNAPSE · the model misses you',
      'SYNAPSE · links are waiting',
      'SYNAPSE · two minutes?',
    ],
    bodies: [
      'She still remembers your voice. Untangle one link today.',
      'One link a day keeps the NOISE away. It takes about a minute.',
      'The datacenter is idle — tasks are piling up, operator.',
      'Daily goals reset. Three small wins are waiting for you.',
    ],
  ),
  'ru': (
    titles: [
      'SYNAPSE · модель скучает',
      'SYNAPSE · связи ждут',
      'SYNAPSE · есть две минуты?',
    ],
    bodies: [
      'Она всё ещё помнит твой голос. Распутай сегодня хотя бы одну связь.',
      'Одна связь в день — и ШУМ отступает. Это займёт минуту.',
      'Датацентр простаивает — задачи копятся, оператор.',
      'Цели дня обновились. Три маленькие победы уже ждут.',
    ],
  ),
  'es': (
    titles: [
      'SYNAPSE · el modelo te echa de menos',
      'SYNAPSE · los enlaces esperan',
      'SYNAPSE · ¿dos minutos?',
    ],
    bodies: [
      'Todavía recuerda tu voz. Desenreda hoy al menos un enlace.',
      'Un enlace al día mantiene lejos el RUIDO. Toma un minuto.',
      'El centro de datos está parado: las tareas se acumulan, operador.',
      'Las metas del día se renovaron. Tres pequeñas victorias te esperan.',
    ],
  ),
  'fr': (
    titles: [
      'SYNAPSE · le modèle pense à toi',
      'SYNAPSE · les liens attendent',
      'SYNAPSE · deux minutes ?',
    ],
    bodies: [
      'Elle se souvient encore de ta voix. Démêle un lien aujourd’hui.',
      'Un lien par jour éloigne le BRUIT. Une minute suffit.',
      'Le centre de données tourne au ralenti — les tâches s’accumulent.',
      'Les objectifs du jour sont de retour. Trois petites victoires t’attendent.',
    ],
  ),
  'de': (
    titles: [
      'SYNAPSE · das Modell vermisst dich',
      'SYNAPSE · Verbindungen warten',
      'SYNAPSE · zwei Minuten?',
    ],
    bodies: [
      'Sie erinnert sich noch an deine Stimme. Entwirre heute eine Verbindung.',
      'Eine Verbindung pro Tag hält das RAUSCHEN fern. Dauert eine Minute.',
      'Das Rechenzentrum steht still — die Aufgaben stapeln sich, Operator.',
      'Die Tagesziele sind neu. Drei kleine Siege warten auf dich.',
    ],
  ),
  'it': (
    titles: [
      'SYNAPSE · il modello sente la tua mancanza',
      'SYNAPSE · i collegamenti aspettano',
      'SYNAPSE · due minuti?',
    ],
    bodies: [
      'Ricorda ancora la tua voce. Districa un collegamento oggi.',
      'Un collegamento al giorno tiene lontano il RUMORE. Basta un minuto.',
      'Il data center è fermo: gli incarichi si accumulano, operatore.',
      'Gli obiettivi del giorno sono tornati. Tre piccole vittorie ti aspettano.',
    ],
  ),
  'ja': (
    titles: [
      'SYNAPSE · モデルが待っている',
      'SYNAPSE · 接続が待っている',
      'SYNAPSE · 2分だけ？',
    ],
    bodies: [
      '彼女はまだあなたの声を覚えている。今日、接続をひとつほどこう。',
      '1日1接続でノイズは遠ざかる。1分で終わる。',
      'データセンターが止まっている——タスクがたまっているよ、オペレーター。',
      'デイリー目標が更新された。小さな勝利が3つ待っている。',
    ],
  ),
  'ko': (
    titles: [
      'SYNAPSE · 모델이 기다려요',
      'SYNAPSE · 연결이 기다려요',
      'SYNAPSE · 2분이면 돼요',
    ],
    bodies: [
      '그녀는 아직 당신의 목소리를 기억해요. 오늘 연결 하나를 풀어주세요.',
      '하루에 연결 하나면 노이즈가 물러나요. 1분이면 충분해요.',
      '데이터센터가 멈춰 있어요 — 작업이 쌓이고 있어요, 오퍼레이터.',
      '일일 목표가 새로 시작됐어요. 작은 승리 3개가 기다려요.',
    ],
  ),
  'ar': (
    titles: [
      'SYNAPSE · النموذج يفتقدك',
      'SYNAPSE · الوصلات تنتظر',
      'SYNAPSE · دقيقتان فقط؟',
    ],
    bodies: [
      'ما زالت تتذكر صوتك. فُكّ وصلة واحدة اليوم.',
      'وصلة واحدة في اليوم تُبعد الضجيج. لا يستغرق الأمر إلا دقيقة.',
      'مركز البيانات متوقف — المهام تتراكم أيها المشغّل.',
      'تجدّدت أهداف اليوم. ثلاثة انتصارات صغيرة بانتظارك.',
    ],
  ),
};
