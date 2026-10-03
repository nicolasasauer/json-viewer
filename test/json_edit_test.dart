import 'package:flutter_test/flutter_test.dart';
import 'package:json_viewer/src/json_edit.dart';

void main() {
  Map<String, Object?> doc() => {
    'name': 'Ada',
    'tags': ['a', 'b'],
    'modules': [
      {'title': 'Analysis', 'ects': 9, 'passed': true, 'grade': null},
    ],
  };

  test('edits return a new root and leave the old one untouched', () {
    final before = doc();
    final after = setAt(before, ['name'], 'Grace') as Map;
    expect(after['name'], 'Grace');
    expect(before['name'], 'Ada');
  });

  test('addField appends or inserts after a key', () {
    expect((addField(doc(), [], 'age', 36) as Map).keys.last, 'age');
    expect(
      (addField(doc(), [], 'age', 36, after: 'name') as Map).keys.toList(),
      ['name', 'age', 'tags', 'modules'],
    );
  });

  test('renameKey keeps the position', () {
    final r = renameKey(doc(), ['tags'], 'labels') as Map;
    expect(r.keys.toList(), ['name', 'labels', 'modules']);
    expect(r['labels'], ['a', 'b']);
  });

  test('move, duplicate and remove', () {
    expect(getAt(move(doc(), ['tags', 1], -1), ['tags']), ['b', 'a']);
    expect((move(doc(), ['name'], 1) as Map).keys.first, 'tags');
    expect(getAt(duplicate(doc(), ['tags', 0]), ['tags']), ['a', 'a', 'b']);
    expect((duplicate(doc(), ['name']) as Map).keys.toList()[1], 'name 2');
    expect((removeAt(doc(), ['tags']) as Map).containsKey('tags'), isFalse);
  });

  test('blankLike keeps the fields of an object', () {
    final module = getAt(doc(), ['modules', 0]);
    expect(blankLike(module), {
      'title': '',
      'ects': 0,
      'passed': false,
      'grade': null,
    });
  });

  test('convert keeps what it can', () {
    expect(convert('42', JsonKind.number), 42);
    expect(convert(7, JsonKind.text), '7');
    expect(convert('x', JsonKind.list), ['x']);
    expect(convert(1, JsonKind.boolean), true);
  });

  test('encodeLike keeps the original formatting style', () {
    final value = {
      'a': [1],
    };
    expect(encodeLike(value, '{"x":1}'), '{"a":[1]}');
    expect(
      encodeLike(value, '{\n    "x": 1\n}'),
      '{\n    "a": [\n        1\n    ]\n}',
    );
    expect(encodeLike(value, '{\n\t"x": 1\n}'), '{\n\t"a": [\n\t\t1\n\t]\n}');
    expect(encodeLike(value, '{\n}'), '{\n  "a": [\n    1\n  ]\n}');
  });
}
