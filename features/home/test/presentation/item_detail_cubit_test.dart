import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/src/domain/entities/item.dart';
import 'package:home/src/domain/repositories/item_repository.dart';
import 'package:home/src/presentation/blocs/item_detail/item_detail_cubit.dart';
import 'package:home/src/presentation/blocs/item_detail/item_detail_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockItemRepository extends Mock implements ItemRepository {}

void main() {
  late _MockItemRepository repository;

  const item = Item(id: '1', title: 't1', description: 'd1');

  setUp(() {
    repository = _MockItemRepository();
  });

  group('ItemDetailCubit', () {
    blocTest<ItemDetailCubit, ItemDetailState>(
      '初始狀態為 ItemDetailLoading',
      build: () => ItemDetailCubit(repository: repository),
      verify: (bloc) {
        expect(bloc.state, isA<ItemDetailLoading>());
      },
    );

    blocTest<ItemDetailCubit, ItemDetailState>(
      '取得成功 → [ItemDetailLoaded]',
      setUp: () {
        when(
          () => repository.fetchItem('1'),
        ).thenAnswer((_) async => const Result.success(item));
      },
      build: () => ItemDetailCubit(repository: repository),
      act: (cubit) => cubit.load('1'),
      expect: () => [
        isA<ItemDetailLoading>(),
        isA<ItemDetailLoaded>().having((s) => s.item, 'item', item),
      ],
    );

    blocTest<ItemDetailCubit, ItemDetailState>(
      '取得失敗 → [ItemDetailError]',
      setUp: () {
        when(() => repository.fetchItem('1')).thenAnswer(
          (_) async => const Result.failure(
            ApiException(code: 'E404', message: 'not found'),
          ),
        );
      },
      build: () => ItemDetailCubit(repository: repository),
      act: (cubit) => cubit.load('1'),
      expect: () => [
        isA<ItemDetailLoading>(),
        isA<ItemDetailError>().having(
          (s) => s.exception,
          'exception',
          isA<ApiException>(),
        ),
      ],
    );
  });
}
