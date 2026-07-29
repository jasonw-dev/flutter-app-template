import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_bloc.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_event.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_state.dart';
import 'package:home/src/presentation/widgets/notification_permission_card.dart';
import 'package:home/src/routes/item_detail_route.dart';
import 'package:localization/localization.dart';
import 'package:permissions/permissions.dart';
import 'package:ui/ui.dart';

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
              return Column(
                children: [
                  // 權限引導卡片:已授權或按過「稍後」時自己收合成 zero-size。
                  NotificationPermissionCard(
                    permissions: context.read<GetIt>()<Permissions>(),
                    store: context.read<GetIt>()<KeyValueStore>(),
                  ),
                  Expanded(child: _buildList(context, state)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, ItemListState state) {
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
        ItemListReady(:final items) when items.isEmpty => AppEmptyView(
          message: context.l10n.homeEmpty,
        ),
        ItemListReady(
          :final items,
          :final hasMore,
          :final loadingMore,
        ) =>
          ListView.builder(
            // 多出來的那一格是底部的載入指示;它 build 時觸發
            // 下一頁。這是最簡單、不需要額外套件的無限捲動做法。
            itemCount: items.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == items.length) {
                // 守衛不可省略:少了它會在每次 rebuild 連續觸發。
                if (!loadingMore) {
                  context.read<ItemListBloc>().add(
                    const ItemListLoadMoreRequested(),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: AppLoadingIndicator(),
                );
              }
              final item = items[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(item.description),
                onTap: () => context.go(ItemDetailRoute(item.id).location),
              );
            },
          ),
      },
    );
  }
}
