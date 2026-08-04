import 'dart:async';

import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:home/home.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permissions/permissions.dart';
import 'package:permissions/testing.dart';

import '_golden_harness.dart';

class _StubRepository extends Mock implements ItemRepository {}

void main() {
  testWidgets(
    'HomePage 有資料',
    (tester) async {
      // 用固定的三筆假資料;golden 不得依賴當下時間或隨機 ID。
      const items = [
        Item(id: '1', title: 'Demo item 1', description: 'Description 1.'),
        Item(id: '2', title: 'Demo item 2', description: 'Description 2.'),
        Item(id: '3', title: 'Demo item 3', description: 'Description 3.'),
      ];
      final repository = _StubRepository();
      final stream = StreamController<List<Item>>.broadcast();
      addTearDown(stream.close);
      when(repository.watchItems).thenAnswer((_) => stream.stream);
      when(() => repository.hasMore).thenReturn(false);
      when(
        repository.refreshItems,
      ).thenAnswer((_) async => const Result<void>.success(null));

      final gi = GetIt.asNewInstance();
      addTearDown(gi.reset);
      gi
        ..registerFactory<ItemListBloc>(
          () => ItemListBloc(repository: repository),
        )
        ..registerSingleton<KeyValueStore>(InMemoryKeyValueStore())
        ..registerSingleton<Permissions>(
          FakePermissions(
            initial: {AppPermission.notifications: PermissionOutcome.granted},
          ),
        );

      await pumpGolden(
        tester,
        RepositoryProvider<GetIt>.value(value: gi, child: const HomePage()),
      );
      stream.add(items);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HomePage),
        matchesGoldenFile('goldens/home_page.png'),
      );
    },
    skip: skipOffLinux,
  );
}
