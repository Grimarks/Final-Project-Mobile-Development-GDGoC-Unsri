import 'package:campusflow/features/courses/data/course_repository.dart';
import 'package:campusflow/features/courses/domain/course.dart';
import 'package:campusflow/features/materials/data/material_repository.dart';
import 'package:campusflow/features/materials/domain/material_item.dart';
import 'package:campusflow/features/materials/presentation/material_detail_screen.dart';
import 'package:campusflow/features/materials/presentation/materials_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menampilkan pesan kosong ketika belum ada materi', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          materialListProvider.overrideWith(_EmptyMaterialList.new),
          courseListProvider.overrideWith(_EmptyCourseList.new),
        ],
        child: const MaterialApp(home: MaterialsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No materials yet'), findsOneWidget);
  });

  testWidgets('menampilkan daftar materi dengan nama mata kuliah', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          materialListProvider.overrideWith(_FakeMaterialList.new),
          courseListProvider.overrideWith(_FakeCourseList.new),
        ],
        child: const MaterialApp(home: MaterialsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('notes.pdf'), findsOneWidget);
    expect(find.textContaining('CS 301'), findsOneWidget);
  });

  testWidgets('tap kartu materi membuka layar detail', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          materialListProvider.overrideWith(_FakeMaterialList.new),
          courseListProvider.overrideWith(_FakeCourseList.new),
        ],
        child: const MaterialApp(home: MaterialsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('notes.pdf'));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialDetailScreen), findsOneWidget);
    expect(find.text('SUMMARIZE'), findsOneWidget);
  });
}

class _EmptyMaterialList extends MaterialList {
  @override
  Future<List<MaterialItem>> build() async => [];
}

class _FakeMaterialList extends MaterialList {
  @override
  Future<List<MaterialItem>> build() async => [
        MaterialItem(
          id: 1,
          filename: 'notes.pdf',
          courseId: 1,
          uploadedAt: DateTime(2026, 9, 2),
          textLength: 500,
          preview: 'Preview text',
        ),
      ];
}

class _EmptyCourseList extends CourseList {
  @override
  Future<List<Course>> build() async => [];
}

class _FakeCourseList extends CourseList {
  @override
  Future<List<Course>> build() async => [
        const Course(id: 1, name: 'CS 301', colorHex: '#4C6FFF'),
      ];
}
