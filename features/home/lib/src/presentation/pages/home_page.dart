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
        body: BlocBuilder<ItemListBloc, ItemListState>(
          builder: (context, state) {
            return switch (state) {
              ItemListLoading() => const AppLoadingIndicator(),
              ItemListError() => AppErrorView(
                message: context.l10n.commonErrorGeneric,
                onRetry: () =>
                    context.read<ItemListBloc>().add(const ItemListRequested()),
                retryLabel: context.l10n.commonRetry,
              ),
              ItemListLoaded(:final items) when items.isEmpty => AppEmptyView(
                message: context.l10n.homeEmpty,
              ),
              ItemListLoaded(:final items) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.description),
                    onTap: () => context.go(ItemDetailRoute(item.id).location),
                  );
                },
              ),
            };
          },
        ),
      ),
    );
  }
}
