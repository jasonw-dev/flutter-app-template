import 'package:home/src/domain/entities/item.dart';

/// `/items` 項目的 DTO。
///
/// 欄位不多不值得引入 json_serializable codegen，手寫 `fromJson`
/// （欄位缺漏時直接 cast 失敗，由 `ApiClient` 收攏為 `ParsingException`）。
class ItemDto {
  /// 以已解析欄位建立。
  const ItemDto({
    required this.id,
    required this.title,
    required this.description,
  });

  /// 由 JSON map 建立；缺欄位時 cast 失敗並向外拋出。
  factory ItemDto.fromJson(Map<String, dynamic> json) => ItemDto(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
  );

  /// 由 domain 型別建立,供快取寫入時使用。
  factory ItemDto.fromEntity(Item item) => ItemDto(
    id: item.id,
    title: item.title,
    description: item.description,
  );

  /// 項目識別碼。
  final String id;

  /// 標題。
  final String title;

  /// 描述。
  final String description;

  /// 轉為 domain 型別 [Item]。
  Item toEntity() => Item(id: id, title: title, description: description);

  /// 轉回 JSON map,供本地快取寫入。
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
  };
}
