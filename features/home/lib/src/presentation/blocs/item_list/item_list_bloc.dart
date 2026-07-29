import 'package:bloc/bloc.dart';
import 'package:core/core.dart';
import 'package:home/src/domain/entities/item.dart';
import 'package:home/src/domain/repositories/item_repository.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_event.dart';
import 'package:home/src/presentation/blocs/item_list/item_list_state.dart';

/// 項目清單頁的 bloc(spec §4.2 典範實作:純 Dart,不 import Flutter)。
///
/// 用 Bloc 而非 Cubit 的理由(conventions §2 第 1 條):有兩個觸發來源
/// ——使用者的下拉刷新,以及 repository 的 stream 推送。
///
/// 對照組是 `LoginCubit` 與 `ItemDetailCubit`:兩者都只有使用者在該頁
/// 的操作這一個觸發來源。
///
/// 清單資料來自 [ItemRepository.watchItems],刷新狀態來自 bloc 自己的
/// 欄位,兩者在 `_emitReady()` 合成同一個 state。
class ItemListBloc extends Bloc<ItemListEvent, ItemListState> {
  /// 以 [repository] 建立。
  ItemListBloc({required ItemRepository repository})
    : _repository = repository,
      super(const ItemListInitial()) {
    on<ItemListRequested>(_onItemListRequested);
    on<ItemListRefreshRequested>(_onItemListRefreshRequested);
    on<ItemListLoadMoreRequested>(_onItemListLoadMoreRequested);
  }

  final ItemRepository _repository;
  bool _refreshing = false;
  bool _loadingMore = false;
  AppException? _lastError;
  List<Item> _items = const [];

  Future<void> _onItemListRequested(
    ItemListRequested event,
    Emitter<ItemListState> emit,
  ) async {
    // 不 await:畫面要立刻吃到快取,不等網路。
    add(const ItemListRefreshRequested());
    // emit.forEach 會長時間不結束,這是刻意的——它是清單資料的來源。
    await emit.forEach<List<Item>>(
      _repository.watchItems(),
      onData: (items) {
        _items = items;
        return ItemListReady(
          items: items,
          refreshing: _refreshing,
          lastError: _lastError,
        );
      },
    );
  }

  Future<void> _onItemListRefreshRequested(
    ItemListRefreshRequested event,
    Emitter<ItemListState> emit,
  ) async {
    _refreshing = true;
    _emitReady(emit);
    final result = await _repository.refreshItems();
    _refreshing = false;
    _lastError = result.fold(
      onSuccess: (_) => null,
      // 取消是預期中的控制流,當成沒發生(conventions §9(a))。
      onFailure: (exception) =>
          exception is CancelledException ? null : exception,
    );
    // 成功時不在這裡 emit 清單——清單會從 watchItems() 那條路自己來。
    // 這裡只負責把 refreshing / lastError 這兩個旗標推出去。
    _emitReady(emit);
  }

  Future<void> _onItemListLoadMoreRequested(
    ItemListLoadMoreRequested event,
    Emitter<ItemListState> emit,
  ) async {
    if (_loadingMore || !_repository.hasMore) {
      return;
    }
    _loadingMore = true;
    _emitReady(emit);
    // loadMore 的失敗不清掉清單、也不寫進 lastError——已載入的內容必須
    // 留著,底部顯示重試列即可(見 conventions §6.1)。
    await _repository.loadMore();
    _loadingMore = false;
    _emitReady(emit);
  }

  void _emitReady(Emitter<ItemListState> emit) => emit(
    ItemListReady(
      items: _items,
      refreshing: _refreshing,
      loadingMore: _loadingMore,
      hasMore: _repository.hasMore,
      lastError: _lastError,
    ),
  );
}
