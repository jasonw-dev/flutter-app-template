import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_bloc.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_event.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_state.dart';
import 'package:localization/localization.dart';
import 'package:navigation/navigation.dart';

/// 首頁:項目清單。
class HomePage extends StatelessWidget {
  /// 建立首頁。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          context.read<GetIt>()<ItemListBloc>()..add(const ItemListRequested()),
      child: AppPageScaffold(
        title: context.l10n.homeTitle,
        // 重抓失敗時只彈 SnackBar,不整頁換成錯誤畫面——舊快取仍是可用資料。
        body: BlocListener<ItemListBloc, ItemListState>(
          listenWhen: (previous, current) =>
              current is ItemListReady && current.lastError != null,
          listener: (context, state) =>
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.commonErrorGeneric)),
              ),
          child: BlocBuilder<ItemListBloc, ItemListState>(
            builder: (context, state) {
              return RefreshIndicator(
                onRefresh: () async => context.read<ItemListBloc>().add(
                  const ItemListRefreshRequested(),
                ),
                child: switch (state) {
                  ItemListInitial() => const AppLoadingIndicator(),
                  // 沒資料且還在抓 → loading,不能顯示空狀態。少了這條,
                  // 首次安裝啟動會先閃一次「沒有資料」再跳出清單,因為
                  // 無快取時 watchItems() 的第一個事件就是空清單。
                  ItemListReady(:final items, :final refreshing)
                      when items.isEmpty && refreshing =>
                    const AppLoadingIndicator(),
                  ItemListReady(:final items) when items.isEmpty =>
                    AppEmptyView(message: context.l10n.homeEmpty),
                  ItemListReady(:final items) => ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.title),
                        subtitle: Text(item.description),
                        onTap: () =>
                            context.go(ItemDetailRoute(item.id).location),
                      );
                    },
                  ),
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
