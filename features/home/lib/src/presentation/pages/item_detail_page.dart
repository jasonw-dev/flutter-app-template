import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:home/src/presentation/blocs/item_detail/item_detail_cubit.dart';
import 'package:home/src/presentation/blocs/item_detail/item_detail_state.dart';
import 'package:localization/localization.dart';
import 'package:ui/ui.dart';

/// 項目詳情頁。
class ItemDetailPage extends StatelessWidget {
  /// 以項目識別碼 [id] 建立詳情頁。
  const ItemDetailPage({required this.id, super.key});

  /// 項目識別碼。
  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = context.read<GetIt>()<ItemDetailCubit>();
        // 進頁面即觸發載入;結果由 state 反映,呼叫端不需要等它。
        unawaited(cubit.load(id));
        return cubit;
      },
      child: AppPageScaffold(
        title: context.l10n.homeDetailTitle,
        body: BlocBuilder<ItemDetailCubit, ItemDetailState>(
          builder: (context, state) {
            return switch (state) {
              ItemDetailLoading() => const AppLoadingIndicator(),
              ItemDetailError() => AppErrorView(
                message: context.l10n.commonErrorGeneric,
                onRetry: () =>
                    unawaited(context.read<ItemDetailCubit>().load(id)),
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
