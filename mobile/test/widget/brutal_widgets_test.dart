import 'package:campusflow/core/theme/brutal_decorations.dart';
import 'package:campusflow/core/theme/colors.dart';
import 'package:campusflow/core/widgets/brutal_button.dart';
import 'package:campusflow/core/widgets/brutal_card.dart';
import 'package:campusflow/core/widgets/brutal_chip.dart';
import 'package:campusflow/core/widgets/priority_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

/// Mencari BoxDecoration dari Container pertama yang benar-benar punya
/// decoration di dalam sebuah widget — bukan sekadar Container pertama,
/// karena AnimatedContainer (dipakai BrutalButton) membungkus child-nya
/// dengan Container internal ber-decoration null.
BoxDecoration decorationOf(WidgetTester tester, Finder finder) {
  final containers = tester.widgetList<Container>(
    find.descendant(of: finder, matching: find.byType(Container)),
  );
  final container = containers.firstWhere((c) => c.decoration != null);
  return container.decoration! as BoxDecoration;
}

void main() {
  group('BrutalCard', () {
    testWidgets('memakai hard shadow tanpa blur', (tester) async {
      await tester.pumpWidget(wrap(const BrutalCard(child: Text('halo'))));

      final decoration = decorationOf(tester, find.byType(BrutalCard));
      expect(decoration.boxShadow!.first.blurRadius, 0);
      expect(decoration.boxShadow!.first.offset, const Offset(4, 4));
      expect(decoration.boxShadow!.first.color, AppColors.ink);
    });

    testWidgets('leftStripe mengganti border kiri dengan warna mata kuliah',
        (tester) async {
      await tester.pumpWidget(
        wrap(const BrutalCard(leftStripe: AppColors.warning, child: Text('x'))),
      );

      final border = decorationOf(tester, find.byType(BrutalCard)).border! as Border;
      expect(border.left.color, AppColors.warning);
      expect(border.left.width, 6);
      expect(border.top.color, AppColors.ink);
    });

    testWidgets('onTap memanggil callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(BrutalCard(onTap: () => tapped = true, child: const Text('tap'))),
      );

      await tester.tap(find.text('tap'));
      expect(tapped, isTrue);
    });
  });

  group('BrutalButton', () {
    testWidgets('label selalu ditampilkan kapital', (tester) async {
      await tester.pumpWidget(
        wrap(BrutalButton(label: 'Plan my day', onPressed: () {})),
      );

      expect(find.text('PLAN MY DAY'), findsOneWidget);
    });

    testWidgets('bayangan menyusut jadi 2px saat ditekan', (tester) async {
      await tester.pumpWidget(wrap(BrutalButton(label: 'go', onPressed: () {})));

      final gesture = await tester.press(find.byType(BrutalButton));
      await tester.pump();

      final decoration = decorationOf(tester, find.byType(BrutalButton));
      expect(decoration.boxShadow!.first.offset, const Offset(2, 2));

      await gesture.up();
    });

    testWidgets('menampilkan spinner dan mengabaikan tap saat loading',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(BrutalButton(label: 'save', loading: true, onPressed: () => taps++)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(BrutalButton));
      expect(taps, 0);
    });
  });

  group('PriorityBlock', () {
    testWidgets('memetakan prioritas ke warna Design.md', (tester) async {
      expect(PriorityBlock.colorFor('high'), AppColors.danger);
      expect(PriorityBlock.colorFor('medium'), AppColors.warning);
      expect(PriorityBlock.colorFor('low'), AppColors.success);
    });

    testWidgets('merender teks kapital', (tester) async {
      await tester.pumpWidget(wrap(const PriorityBlock(priority: 'high')));
      expect(find.text('HIGH'), findsOneWidget);
    });
  });

  group('BrutalChip', () {
    testWidgets('chip terpilih memakai blok tinta penuh', (tester) async {
      await tester.pumpWidget(
        wrap(BrutalChip(label: 'All', selected: true, onTap: () {})),
      );

      final decoration = decorationOf(tester, find.byType(BrutalChip));
      expect(decoration.color, AppColors.ink);
    });

    testWidgets('chip tidak terpilih berlatar putih', (tester) async {
      await tester.pumpWidget(
        wrap(BrutalChip(label: 'Done', selected: false, onTap: () {})),
      );

      final decoration = decorationOf(tester, find.byType(BrutalChip));
      expect(decoration.color, AppColors.surface);
    });
  });

  group('token Brutal', () {
    test('shadow tidak pernah punya blur', () {
      expect(Brutal.shadow().first.blurRadius, 0);
      expect(Brutal.shadow(offset: 6).first.offset, const Offset(6, 6));
    });

    test('radius sudut maksimal 4px', () {
      expect(Brutal.radius, lessThanOrEqualTo(4));
    });
  });
}
