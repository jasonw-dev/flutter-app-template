import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:home/src/domain/entities/item.dart';
import 'package:home/src/domain/repositories/item_repository.dart';
import 'package:home/src/presentation/blocs/item_detail/item_detail_bloc.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_bloc.dart';
import 'package:home/src/presentation/pages/home_page.dart';
import 'package:home/src/presentation/pages/item_detail_page.dart';
import 'package:localization/localization.dart';
import 'package:localization/testing.dart';
import 'package:mocktail/mocktail.dart';

class _MockItemRepository extends Mock implements ItemRepository {}

final _l10n = AppLocalizationsEn();

const _items = [
  Item(id: '1', title: 't1', description: 'd1'),
  Item(id: '2', title: 't2', description: 'd2'),
  Item(id: '3', title: 't3', description: 'd3'),
  Item(id: '4', title: 't4', description: 'd4'),
  Item(id: '5', title: 't5', description: 'd5'),
];

/// 用獨立容器包住待測頁面。
///
/// page 透過 `context.read<GetIt>()` 取用容器,測試因此不必碰全域單例
/// (見 docs/conventions.md §5 DI 規範)。
Widget _wrap(GetIt gi, Widget home) => RepositoryProvider<GetIt>.value(
  value: gi,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

Widget _homeApp(GetIt gi) => _wrap(gi, const HomePage());

Widget _detailApp(GetIt gi) => _wrap(gi, const ItemDetailPage(id: '1'));

void main() {
  late _MockItemRepository repository;
  late StreamController<List<Item>> itemStream;
  final gi = GetIt.asNewInstance();

  /// 讓 HomePage 進到「有資料」狀態:餵一次 stream 事件並讓畫面收斂。
  Future<void> emitItems(WidgetTester tester, List<Item> items) async {
    itemStream.add(items);
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockItemRepository();
    itemStream = StreamController<List<Item>>.broadcast();
    when(repository.watchItems).thenAnswer((_) => itemStream.stream);
    when(
      repository.refreshItems,
    ).thenAnswer((_) async => const Result<void>.success(null));
    gi
      ..registerFactory<ItemListBloc>(
        () => ItemListBloc(repository: repository),
      )
      ..registerFactory<ItemDetailBloc>(
        () => ItemDetailBloc(repository: repository),
      );
  });

  tearDown(() async {
    await itemStream.close();
    await gi.reset();
  });

  group('HomePage', () {
    testWidgets('冷啟動(無快取、刷新中)→ 顯示載入指示而不是空狀態', (tester) async {
      // 這條釘住 home_page.dart 的 `items.isEmpty && refreshing` 分支:
      // 少了它,首次安裝啟動會先閃一次「沒有資料」再跳出清單。
      //
      // 註:ItemListInitial 在畫面上幾乎觀察不到——BlocProvider 一建好就
      // 送出 ItemListRequested,bloc 隨即 emit ItemListReady。該狀態的
      // 存在由 item_list_bloc_test 的「初始狀態」那條斷言涵蓋。
      when(repository.refreshItems).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Result<void>.success(null);
      });

      await tester.pumpWidget(_homeApp(gi));
      await tester.pump();
      itemStream.add(const []);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(_l10n.homeEmpty), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('有資料 → 顯示清單', (tester) async {
      await tester.pumpWidget(_homeApp(gi));
      await emitItems(tester, _items);

      expect(find.byType(ListTile), findsNWidgets(5));
      expect(find.text('t1'), findsOneWidget);
    });

    testWidgets('刷新完成且清單為空 → 顯示空狀態文案', (tester) async {
      await tester.pumpWidget(_homeApp(gi));
      await emitItems(tester, const []);

      expect(find.text(_l10n.homeEmpty), findsOneWidget);
    });

    testWidgets('刷新失敗 → 彈 SnackBar,清單仍在(不整頁換成錯誤畫面)', (tester) async {
      await tester.pumpWidget(_homeApp(gi));
      await emitItems(tester, _items);

      when(repository.refreshItems).thenAnswer(
        (_) async => const Result<void>.failure(UnauthorizedException()),
      );
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(find.text(_l10n.commonErrorGeneric), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(5));
    });
  });

  group('ItemDetailPage', () {
    testWidgets('Loading 顯示載入指示', (tester) async {
      when(() => repository.fetchItem('1')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Result.success(
          Item(id: '1', title: 't1', description: 'd1'),
        );
      });

      await tester.pumpWidget(_detailApp(gi));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('Error 顯示重試按鈕，點擊後重新發送請求', (tester) async {
      when(() => repository.fetchItem('1')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return const Result.failure(UnauthorizedException());
      });

      await tester.pumpWidget(_detailApp(gi));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.commonErrorGeneric), findsOneWidget);
      expect(find.text(_l10n.commonRetry), findsOneWidget);

      await tester.tap(find.text(_l10n.commonRetry));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      verify(() => repository.fetchItem('1')).called(2);
    });

    testWidgets('Loaded 顯示標題與描述', (tester) async {
      when(() => repository.fetchItem('1')).thenAnswer(
        (_) async =>
            const Result.success(Item(id: '1', title: 't1', description: 'd1')),
      );

      await tester.pumpWidget(_detailApp(gi));
      await tester.pump();
      await tester.pump();

      expect(find.text('t1'), findsOneWidget);
      expect(find.text('d1'), findsOneWidget);
    });
  });
}
