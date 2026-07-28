import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/src/domain/entities/item.dart';
import 'package:home/src/domain/repositories/item_repository.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_bloc.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_event.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockItemRepository extends Mock implements ItemRepository {}

void main() {
  late _MockItemRepository repository;
  late StreamController<List<Item>> items;

  const cached = [Item(id: '1', title: 't1', description: 'd1')];
  const fresh = [
    Item(id: '1', title: 't1', description: 'd1'),
    Item(id: '2', title: 't2', description: 'd2'),
  ];

  setUp(() {
    repository = _MockItemRepository();
    items = StreamController<List<Item>>.broadcast();
    when(repository.watchItems).thenAnswer((_) => items.stream);
  });

  tearDown(() => items.close());

  group('ItemListBloc', () {
    blocTest<ItemListBloc, ItemListState>(
      '初始狀態為 ItemListInitial',
      build: () => ItemListBloc(repository: repository),
      verify: (bloc) => expect(bloc.state, isA<ItemListInitial>()),
    );

    blocTest<ItemListBloc, ItemListState>(
      'Requested 會順帶觸發一次 refresh,並開始跟隨 watchItems',
      setUp: () => when(
        repository.refreshItems,
      ).thenAnswer((_) async => const Result<void>.success(null)),
      build: () => ItemListBloc(repository: repository),
      act: (bloc) async {
        bloc.add(const ItemListRequested());
        await Future<void>.delayed(Duration.zero);
        items.add(cached);
      },
      expect: () => [
        // refresh 開始
        isA<ItemListReady>()
            .having((s) => s.items, 'items', isEmpty)
            .having((s) => s.refreshing, 'refreshing', isTrue),
        // refresh 結束
        isA<ItemListReady>().having((s) => s.refreshing, 'refreshing', isFalse),
        // stream 推來的快取
        isA<ItemListReady>().having((s) => s.items, 'items', cached),
      ],
      verify: (_) => verify(repository.refreshItems).called(1),
    );

    blocTest<ItemListBloc, ItemListState>(
      'stream 推送新清單時狀態跟著更新',
      build: () => ItemListBloc(repository: repository),
      act: (bloc) async {
        bloc.add(const ItemListRequested());
        await Future<void>.delayed(Duration.zero);
        items
          ..add(cached)
          ..add(fresh);
      },
      setUp: () => when(
        repository.refreshItems,
      ).thenAnswer((_) async => const Result<void>.success(null)),
      skip: 2, // 略過 refresh 的兩個旗標狀態
      expect: () => [
        isA<ItemListReady>().having((s) => s.items, 'items', cached),
        isA<ItemListReady>().having((s) => s.items, 'items', fresh),
      ],
    );

    blocTest<ItemListBloc, ItemListState>(
      '刷新失敗 → lastError 有值,但 items 保留舊資料',
      setUp: () => when(repository.refreshItems).thenAnswer(
        (_) async => const Result<void>.failure(
          ApiException(code: 'E500', message: 'boom'),
        ),
      ),
      build: () => ItemListBloc(repository: repository),
      act: (bloc) async {
        bloc.add(const ItemListRequested());
        await Future<void>.delayed(Duration.zero);
        items.add(cached);
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ItemListRefreshRequested());
      },
      expect: () => [
        isA<ItemListReady>().having((s) => s.refreshing, 'refreshing', isTrue),
        isA<ItemListReady>()
            .having((s) => s.refreshing, 'refreshing', isFalse)
            .having((s) => s.lastError, 'lastError', isA<ApiException>()),
        isA<ItemListReady>().having((s) => s.items, 'items', cached),
        isA<ItemListReady>().having((s) => s.refreshing, 'refreshing', isTrue),
        isA<ItemListReady>()
            .having((s) => s.items, 'items', cached)
            .having((s) => s.lastError, 'lastError', isA<ApiException>()),
      ],
    );

    blocTest<ItemListBloc, ItemListState>(
      'CancelledException 視為沒發生:lastError 保持 null',
      setUp: () => when(repository.refreshItems).thenAnswer(
        (_) async => const Result<void>.failure(CancelledException()),
      ),
      build: () => ItemListBloc(repository: repository),
      act: (bloc) => bloc.add(const ItemListRefreshRequested()),
      expect: () => [
        isA<ItemListReady>().having((s) => s.refreshing, 'refreshing', isTrue),
        isA<ItemListReady>()
            .having((s) => s.refreshing, 'refreshing', isFalse)
            .having((s) => s.lastError, 'lastError', isNull),
      ],
    );
  });
}
