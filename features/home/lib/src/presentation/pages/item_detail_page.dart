import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:home/src/presentation/blocs/item_detail/item_detail_bloc.dart';
import 'package:home/src/presentation/blocs/item_detail/item_detail_event.dart';
import 'package:home/src/presentation/blocs/item_detail/item_detail_state.dart';
import 'package:localization/localization.dart';

/// 項目詳情頁。
class ItemDetailPage extends StatelessWidget {
  /// 以項目識別碼 [id] 建立詳情頁。
  const ItemDetailPage({required this.id, super.key});

  /// 項目識別碼。
  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          context.read<GetIt>()<ItemDetailBloc>()..add(ItemDetailRequested(id)),
      child: AppPageScaffold(
        title: context.l10n.homeDetailTitle,
        body: BlocBuilder<ItemDetailBloc, ItemDetailState>(
          builder: (context, state) {
            return switch (state) {
              ItemDetailLoading() => const AppLoadingIndicator(),
              ItemDetailError() => AppErrorView(
                message: context.l10n.commonErrorGeneric,
                onRetry: () =>
                    context.read<ItemDetailBloc>().add(ItemDetailRequested(id)),
                retryLabel: context.l10n.commonRetry,
              ),
              ItemDetailLoaded(:final item) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(item.description),
                  ],
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}
