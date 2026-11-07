/// Maps a model-provided name to a local id.
///
/// Exact normalized matches win; containment is allowed only when unique;
/// fuzzy matching is a last resort and must be unique. Ambiguity returns null,
/// leaving the field for the user to choose.
String? matchLocalName(
  String? suggested,
  Iterable<({String id, String name})> options,
) {
  if (suggested == null) {
    return null;
  }
  final String target = _normalize(suggested);
  if (target.isEmpty) {
    return null;
  }

  final List<({String id, String name})> exact = options
      .where((({String id, String name}) option) =>
          _normalize(option.name) == target)
      .toList(growable: false);
  if (exact.length == 1) {
    return exact.single.id;
  }
  if (exact.length > 1) {
    return null;
  }

  final List<({String id, String name})> contains = options
      .where((({String id, String name}) option) {
    final String name = _normalize(option.name);
    return name.startsWith(target) ||
        target.startsWith(name) ||
        name.endsWith(target) ||
        target.endsWith(name);
  }).toList(growable: false);
  if (contains.length == 1) {
    return contains.single.id;
  }
  if (contains.length > 1) {
    return null;
  }

  final int threshold = target.length <= 5 ? 1 : 2;
  final List<({String id, int distance})> distances = options
      .map(
        (({String id, String name}) option) => (
          id: option.id,
          distance: _distance(target, _normalize(option.name)),
        ),
      )
      .toList(growable: false);
  if (distances.isEmpty) {
    return null;
  }
  final int best = distances
      .map((({String id, int distance}) item) => item.distance)
      .reduce((int a, int b) => a < b ? a : b);
  if (best > threshold) {
    return null;
  }
  final List<({String id, int distance})> winners = distances
      .where((({String id, int distance}) item) => item.distance == best)
      .toList(growable: false);
  return winners.length == 1 ? winners.single.id : null;
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

int _distance(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }

  final List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
  final List<int> current = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final int cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      final int insertion = current[j] + 1;
      final int deletion = previous[j + 1] + 1;
      final int substitution = previous[j] + cost;
      current[j + 1] = _min3(insertion, deletion, substitution);
    }
    for (var j = 0; j <= b.length; j++) {
      previous[j] = current[j];
    }
  }
  return previous[b.length];
}

int _min3(int a, int b, int c) {
  var result = a;
  if (b < result) {
    result = b;
  }
  if (c < result) {
    result = c;
  }
  return result;
}
