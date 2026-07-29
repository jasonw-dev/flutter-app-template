import 'package:core/core.dart';
import 'package:get_it/get_it.dart';
import 'package:home/src/data/repositories/item_repository_impl.dart';
import 'package:home/src/domain/repositories/item_repository.dart';
import 'package:home/src/presentation/blocs/item_detail/item_detail_cubit.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_bloc.dart';

/// 註冊 home feature 的依賴(供 app 以 `{{feature-registry}}` 插入)。
void registerHomeFeature(GetIt gi) {
  gi
    // repository 是 lazySingleton(多頁共用同一份快取與廣播),bloc 是
    // factory。dispose 由容器負責——bloc 生命週期比 repository 短,
    // 讓 bloc 去 close 會讓下一個頁面拿到已關閉的 stream。
    ..registerLazySingleton<ItemRepository>(
      () => ItemRepositoryImpl(
        client: gi<ApiClient>(),
        store: gi<KeyValueStore>(),
      ),
      dispose: (repository) => repository.dispose(),
    )
    ..registerFactory<ItemListBloc>(
      () => ItemListBloc(repository: gi<ItemRepository>()),
    )
    ..registerFactory<ItemDetailCubit>(
      () => ItemDetailCubit(repository: gi<ItemRepository>()),
    );
}
