import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/biographies/models/biography.dart';
import 'package:otzaria/tools/biographies/repository/biographies_repository.dart';

Biography _bio(String name, {List<String> appelations = const []}) =>
    Biography(id: name.hashCode, name: name, appelations: appelations);

void main() {
  group('BiographiesRepository.filter', () {
    test('שאילתה ריקה מחזירה את כל הערכים כמות שהם', () {
      final entries = [_bio('רבי עקיבא'), _bio('אביי')];
      expect(BiographiesRepository.filter(entries, '   '), same(entries));
    });

    test('מתאים גם לפי כינוי', () {
      final entries = [
        _bio('רבי משה סופר', appelations: ['החתם סופר']),
      ];
      expect(
        BiographiesRepository.filter(entries, 'החתם סופר').single.name,
        'רבי משה סופר',
      );
    });

    test('מדויק < מתחיל ב- < מילה שלמה < מכיל < רק בכינוי', () {
      final entries = [
        _bio('פלוני', appelations: ['רש״י']),
        _bio('שמעון רש״יא'),
        _bio('רבי רש״י הגדול'),
        _bio('רש״י הקדוש'),
        _bio('רש״י'),
      ];

      expect(
        BiographiesRepository.filter(entries, 'רש״י').map((b) => b.name),
        ['רש״י', 'רש״י הקדוש', 'רבי רש״י הגדול', 'שמעון רש״יא', 'פלוני'],
      );
    });

    test('בדירוג שווה ממוין לפי שם', () {
      final entries = [_bio('אב יוסף'), _bio('אב דוד')];
      expect(BiographiesRepository.filter(entries, 'אב').map((b) => b.name), [
        'אב דוד',
        'אב יוסף',
      ]);
    });
  });
}
