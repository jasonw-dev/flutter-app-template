import 'package:bloc/bloc.dart';
import 'package:home/src/domain/repositories/item_repository.dart';
import 'package:home/src/presentation/blocs/item_detail/item_detail_state.dart';

/// 項目詳情頁的 cubit。
///
/// 用 Cubit 而非 Bloc 的理由(conventions §2 第 1 條):詳情頁不快取,只有
/// 「進頁面時抓一次」與「錯誤後重試」兩個使用者觸發,沒有 stream 來源,
/// 屬於單一觸發來源。
///
/// 對照組是 [ItemListBloc](../item_list/item_list_bloc.dart):它同時被
/// 使用者的下拉刷新與 repository 的 stream 推送驅動,是兩個觸發來源。
class ItemDetailCubit extends Cubit<ItemDetailState> {
  /// 以 [repository] 建立。
  ItemDetailCubit({required ItemRepository repository})
    : _repository = repository,
      super(const ItemDetailLoading());

  final ItemRepository _repository;

  /// 以 [id] 載入項目;重試時重複呼叫即可。
  Future<void> load(String id) async {
    emit(const ItemDetailLoading());
    final result = await _repository.fetchItem(id);
    result.fold(
      onSuccess: (item) => emit(ItemDetailLoaded(item)),
      onFailure: (exception) => emit(ItemDetailError(exception)),
    );
  }
}
