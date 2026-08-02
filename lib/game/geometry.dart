import 'dart:math' as math;

/// Геометрия головоломки — прямой порт из index.html.
typedef Pt = List<double>; // [x, y]

bool ccw(Pt a, Pt b, Pt c) =>
    (c[1] - a[1]) * (b[0] - a[0]) > (b[1] - a[1]) * (c[0] - a[0]);

/// Пересекаются ли отрезки p1-p2 и p3-p4.
bool segX(Pt p1, Pt p2, Pt p3, Pt p4) =>
    ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4);

/// Есть ли у рёбер общий узел.
bool shares(List<int> e, List<int> f) =>
    e[0] == f[0] || e[0] == f[1] || e[1] == f[0] || e[1] == f[1];

double dist(Pt a, Pt b) {
  final x = a[0] - b[0], y = a[1] - b[1];
  return math.sqrt(x * x + y * y);
}

/// Число пересечений. Мосты (bridges) живут на верхнем слое и с нижним
/// не пересекаются — как в countCross() исходника.
int countCross(List<Pt> pos, List<List<int>> edges, [Set<int>? bridges]) {
  var c = 0;
  for (var a = 0; a < edges.length; a++) {
    for (var b = a + 1; b < edges.length; b++) {
      if (shares(edges[a], edges[b])) continue;
      if (bridges != null && bridges.contains(a) != bridges.contains(b)) continue;
      if (segX(pos[edges[a][0]], pos[edges[a][1]], pos[edges[b][0]], pos[edges[b][1]])) c++;
    }
  }
  return c;
}
