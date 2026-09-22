import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

void main() {
  test(
    'ellipsize: короткое название остаётся целым, лишние пробелы схлопываются',
    () {
      expect(
        SystemTrayText.ellipsize('  Обзор   клавиатуры  '),
        'Обзор клавиатуры',
      );
    },
  );

  test(
    'ellipsize: длинное название сворачивается в троеточие в пределах длины',
    () {
      final title =
          'Очень длинное название видео, которое не помещается в меню трея целиком';
      final shortened = SystemTrayText.ellipsize(title, maxLength: 20);

      expect(shortened, 'Очень длинное назва…');
      expect(shortened.runes.length, 20);
    },
  );

  test('ellipsize не разрезает эмодзи и составные символы', () {
    final shortened = SystemTrayText.ellipsize(
      '👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦',
      maxLength: 2,
    );

    expect(shortened, '👨‍👩‍👧‍👦…');
  });

  test('limitUtf16 укладывает текст в лимит подсказки Windows', () {
    final text = 'а' * 200;
    final limited = SystemTrayText.limitUtf16(
      text,
      SystemTrayText.windowsToolTipMaxUtf16Length,
    );

    expect(limited.length, lessThanOrEqualTo(127));
    expect(limited, endsWith('…'));
    expect(SystemTrayText.limitUtf16('PeekyCat', 127), 'PeekyCat');
  });

  test('escapeWindowsMenuMnemonics удваивает амперсанд', () {
    expect(
      SystemTrayText.escapeWindowsMenuMnemonics('Tom & Jerry'),
      'Tom && Jerry',
    );
  });
}
