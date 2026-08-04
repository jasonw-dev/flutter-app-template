import 'dart:io';

/// `dart run tool/new_feature.dart <snake_case_name>` 產生器(conventions.md §11)。
///
/// 以 `features/home` 為藍本產生最小「list 切片」feature 骨架,並自動接線到
/// 根 pubspec、`core` 的路由常數、`app` 的 DI/路由/di_smoke_test(以下
/// `{{route-paths}}` / `{{feature-registry}}` 標記行之前插入)。
void main(List<String> arguments) {
  if (arguments.length != 1) {
    _printUsage();
    exit(1);
  }

  final name = arguments.single;
  final error = _validateName(name);
  if (error != null) {
    _printUsage();
    stderr.writeln('原因:$error');
    exit(1);
  }

  final pascal = _toPascalCase(name);
  final camel = _toCamelCase(name);

  try {
    _generateFeature(name: name, pascal: pascal, camel: camel);
    _wireRootPubspec(name);
    _wireRoutePaths(name: name, camel: camel);
    _wireAppPubspec(name);
    _wireComposeDependencies(name: name, pascal: pascal);
    _wireAppRouter(name: name, camel: camel);
    _wireDiSmokeTest(name: name, pascal: pascal);
    _formatDartFiles([
      'features/$name',
      'packages/core/lib/src/navigation/route_paths.dart',
      'app/lib/src/di/compose_dependencies.dart',
      'app/lib/src/router/app_router.dart',
      'app/test/di_smoke_test.dart',
    ]);
  } on Object catch (e) {
    stderr
      ..writeln('✗ 產生中斷:$e')
      ..writeln('請執行:git checkout -- . && rm -rf features/$name')
      ..writeln('然後 fvm flutter pub get 還原 workspace');
    exit(1);
  }

  _printNextSteps(name: name, pascal: pascal, camel: camel);
}

/// 以目前執行本 script 的 dart 執行檔(與 fvm 釘選版本一致)格式化產出/
/// 接線觸及的檔案,確保 `dart format --set-exit-if-changed .` 不會再有差異。
void _formatDartFiles(List<String> paths) {
  final result = Process.runSync(Platform.resolvedExecutable, [
    'format',
    ...paths,
  ]);
  if (result.exitCode != 0) {
    stderr
      ..writeln(result.stdout)
      ..writeln(result.stderr);
    throw StateError('dart format 失敗');
  }
}

void _printUsage() {
  stderr.writeln('用法:fvm dart run tool/new_feature.dart <snake_case_name>');
}

/// 驗證名稱格式、目錄是否已存在、是否為保留名;通過回傳 null,否則回傳原因。
String? _validateName(String name) {
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
    return "名稱須符合 ^[a-z][a-z0-9_]*\$(小寫字母開頭,僅含小寫字母、數字、底線):'$name'";
  }
  if (Directory('features/$name').existsSync()) {
    return 'features/$name 已存在';
  }
  final reserved = {
    'app',
    'dart',
    'flutter',
    'integration_test',
    'test',
    ..._packageNames(),
  };
  if (reserved.contains(name)) {
    return "'$name' 為保留名(app、SDK 保留字或現有 package 名)";
  }
  if (_genericSharedNames.contains(name)) {
    return "'$name' 是萬用共用模組名,本庫禁止。\n"
        '  feature 之間不得互相依賴,而 features/$name 一旦存在就會變成後門——\n'
        '  最後每個 feature 都依賴它,隔離失效。改用以下之一:\n'
        '  · 技術基礎設施 → packages/core\n'
        '  · 共用 UI 元件 → packages/ui\n'
        '  · 一個 feature 需要另一個 feature 擁有的業務資料 →\n'
        '    consumer 自己定義 port + app 寫 adapter,見\n'
        '    docs/how-to/bridge-cross-feature-capability.md';
  }
  return null;
}

/// 禁止的萬用共用模組名。
///
/// 這幾個名字是 feature 隔離失守的標準起手式:名字本身沒有邊界,任何東西都
/// 「算是」共用,於是所有 feature 都依賴它,pubspec 擋的那條線就等於不存在。
const _genericSharedNames = {'shared', 'common', 'utils', 'core_feature'};

Iterable<String> _packageNames() => Directory('packages')
    .listSync()
    .whereType<Directory>()
    .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last);

String _toPascalCase(String snake) => snake
    .split('_')
    .where((s) => s.isNotEmpty)
    .map((s) => s[0].toUpperCase() + s.substring(1))
    .join();

String _toCamelCase(String snake) {
  final pascal = _toPascalCase(snake);
  return pascal[0].toLowerCase() + pascal.substring(1);
}

/// 組出依字母序排序的 `import 'package:...';` 區塊(directives_ordering);
/// [paths] 為 `package:` 之後的路徑,如 `go_router/go_router.dart`。
String _imports(List<String> paths) {
  // 以 `dart:` 開頭的視為 SDK library,不加 `package:` 前綴;並依 lint 的
  // directives_ordering 規則把 dart: 排在 package: 之前。
  final dartLibs =
      paths
          .where((p) => p.startsWith('dart:'))
          .map((p) => "import '$p';")
          .toList()
        ..sort();
  final packages =
      paths
          .where((p) => !p.startsWith('dart:'))
          .map((p) => "import 'package:$p';")
          .toList()
        ..sort();
  return [
    ...dartLibs,
    if (dartLibs.isNotEmpty && packages.isNotEmpty) '',
    ...packages,
  ].join('\n');
}

// ---------------------------------------------------------------------------
// Feature 骨架產生
// ---------------------------------------------------------------------------

void _generateFeature({
  required String name,
  required String pascal,
  required String camel,
}) {
  final root = 'features/$name';
  final files = <String, String>{
    '$root/pubspec.yaml': _pubspecTemplate(name),
    '$root/lib/$name.dart': _barrelTemplate(name: name, pascal: pascal),
    '$root/lib/src/di.dart': _diTemplate(name: name, pascal: pascal),
    '$root/lib/src/routes.dart': _routesTemplate(
      name: name,
      pascal: pascal,
      camel: camel,
    ),
    '$root/lib/src/domain/entities/${name}_entry.dart': _entityTemplate(
      pascal: pascal,
    ),
    '$root/lib/src/domain/repositories/${name}_repository.dart':
        _repositoryTemplate(name: name, pascal: pascal),
    '$root/lib/src/data/dtos/${name}_entry_dto.dart': _dtoTemplate(
      name: name,
      pascal: pascal,
    ),
    '$root/lib/src/data/repositories/${name}_repository_impl.dart':
        _repositoryImplTemplate(name: name, pascal: pascal),
    '$root/lib/src/presentation/blocs/${name}_list/${name}_list_state.dart':
        _blocStateTemplate(name: name, pascal: pascal),
    '$root/lib/src/presentation/blocs/${name}_list/${name}_list_cubit.dart':
        _cubitTemplate(name: name, pascal: pascal),
    '$root/lib/src/presentation/pages/${name}_page.dart': _pageTemplate(
      name: name,
      pascal: pascal,
    ),
    '$root/test/data/${name}_repository_impl_test.dart':
        _repositoryImplTestTemplate(name: name, pascal: pascal),
    '$root/test/presentation/${name}_list_cubit_test.dart': _cubitTestTemplate(
      name: name,
      pascal: pascal,
    ),
    '$root/test/presentation/${name}_page_test.dart': _pageTestTemplate(
      name: name,
      pascal: pascal,
    ),
  };

  for (final entry in files.entries) {
    File(entry.key)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }

  stdout.writeln('✓ 已產生 $root/');
}

String _pubspecTemplate(String name) =>
    '''
name: $name
description: $name 功能:domain/data/presentation 層(項目清單、blocs)。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.12.0

dependencies:
  bloc: ^9.0.0
  core: any
  flutter:
    sdk: flutter
  flutter_bloc: ^9.0.0
  get_it: ^9.0.0
  go_router: ^17.0.0
  localization: any
  ui: any

dev_dependencies:
  bloc_test: ^10.0.0
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
''';

String _barrelTemplate({required String name, required String pascal}) =>
    '''
/// $pascal 功能對外入口。
library;

export 'src/di.dart';
// 以下匯出供組裝層(app)註冊驗證與路由測試;features 之間仍禁止互相依賴
// (pubspec 白名單擋住)。
export 'src/domain/entities/${name}_entry.dart';
export 'src/domain/repositories/${name}_repository.dart';
export 'src/presentation/blocs/${name}_list/${name}_list_cubit.dart';
export 'src/presentation/blocs/${name}_list/${name}_list_state.dart';
export 'src/presentation/pages/${name}_page.dart';
export 'src/routes.dart';
''';

String _diTemplate({required String name, required String pascal}) =>
    '''
${_imports(['get_it/get_it.dart', '$name/src/data/repositories/${name}_repository_impl.dart', '$name/src/domain/repositories/${name}_repository.dart', '$name/src/presentation/blocs/${name}_list/${name}_list_cubit.dart', 'core/core.dart'])}

/// 註冊 $name feature 的依賴(供 app 以 `{{feature-registry}}` 插入)。
void register${pascal}Feature(GetIt gi) {
  gi
    ..registerLazySingleton<${pascal}Repository>(
      () => ${pascal}RepositoryImpl(gi<ApiClient>()),
    )
    ..registerFactory<${pascal}ListCubit>(
      () => ${pascal}ListCubit(repository: gi<${pascal}Repository>()),
    );
}
''';

String _routesTemplate({
  required String name,
  required String pascal,
  required String camel,
}) =>
    '''
${_imports(['go_router/go_router.dart', '$name/src/presentation/pages/${name}_page.dart', 'core/core.dart'])}

/// $name feature 對外提供的路由(供 app 路由表以 `{{feature-registry}}` 插入)。
List<RouteBase> ${camel}Routes() => [
  GoRoute(
    path: RoutePaths.$camel,
    // name 用於自動 screen tracking。命名規則:snake_case、不含動態參數、
    // 跨 feature 唯一(見 docs/conventions.md 6.3)。
    name: '$name',
    builder: (_, _) => const ${pascal}Page(),
  ),
];

/// 導向 $pascal 頁。
///
/// feature 專屬的型別化路由跟 GoRoute 清單同住這個檔(ADR-0006):共用處
/// (`core`)只留路徑常數,兩個人平行開兩個功能才不會同時改到同一個共用檔。
/// 跨 feature 導航請改用 `RoutePaths` 的常數。
class ${pascal}Route {
  /// 建立 $pascal 頁路由。
  const ${pascal}Route();

  /// 完整 location。
  String get location => RoutePaths.$camel;
}
''';

String _entityTemplate({required String pascal}) =>
    '''
/// $pascal 清單項目。
class ${pascal}Entry {
  /// 以已解析欄位建立。
  const ${pascal}Entry({required this.id, required this.title});

  /// 項目識別碼。
  final String id;

  /// 標題。
  final String title;
}
''';

String _repositoryTemplate({required String name, required String pascal}) =>
    '''
${_imports(['core/core.dart', '$name/src/domain/entities/${name}_entry.dart'])}

/// $name 功能的 domain 契約。
// ignore: one_member_abstracts -- 與其他 feature repository 介面一致,對接真實 API 後預期會擴充更多方法
abstract interface class ${pascal}Repository {
  /// 取得 $pascal 清單。
  Future<Result<List<${pascal}Entry>>> fetch${pascal}Entries();
}
''';

String _dtoTemplate({required String name, required String pascal}) =>
    '''
import 'package:$name/src/domain/entities/${name}_entry.dart';

/// `/$name/entries` 項目的 DTO。
///
/// 欄位不多不值得引入 json_serializable codegen,手寫 `fromJson`
/// (欄位缺漏時直接 cast 失敗,由 `ApiClient` 收攏為 `ParsingException`)。
class ${pascal}EntryDto {
  /// 以已解析欄位建立。
  const ${pascal}EntryDto({required this.id, required this.title});

  /// 由 JSON map 建立;缺欄位時 cast 失敗並向外拋出。
  factory ${pascal}EntryDto.fromJson(Map<String, dynamic> json) =>
      ${pascal}EntryDto(
        id: json['id'] as String,
        title: json['title'] as String,
      );

  /// 項目識別碼。
  final String id;

  /// 標題。
  final String title;

  /// 轉為 domain 型別 [${pascal}Entry]。
  ${pascal}Entry toEntity() => ${pascal}Entry(id: id, title: title);
}
''';

String _repositoryImplTemplate({
  required String name,
  required String pascal,
}) =>
    '''
${_imports(['core/core.dart', '$name/src/data/dtos/${name}_entry_dto.dart', '$name/src/domain/entities/${name}_entry.dart', '$name/src/domain/repositories/${name}_repository.dart'])}

/// [${pascal}Repository] 的 HTTP 實作。
class ${pascal}RepositoryImpl implements ${pascal}Repository {
  /// 以 [ApiClient] 建立。
  ${pascal}RepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<${pascal}Entry>>> fetch${pascal}Entries() =>
      _client.get<List<${pascal}Entry>>(
        '/$name/entries',
        parse: (data) {
          final entries =
              (data as Map<String, dynamic>)['entries'] as List<dynamic>;
          return entries
              .map(
                (e) =>
                    ${pascal}EntryDto.fromJson(
                      e as Map<String, dynamic>,
                    ).toEntity(),
              )
              .toList();
        },
      );
}
''';

String _blocStateTemplate({required String name, required String pascal}) =>
    '''
${_imports(['core/core.dart', '$name/src/domain/entities/${name}_entry.dart'])}

/// $pascal 清單頁的狀態(sealed;UI 端須 exhaustive switch 渲染)。
sealed class ${pascal}ListState {
  /// 基底建構子,僅供子類 super 呼叫。
  const ${pascal}ListState();
}

/// 載入中(初始狀態)。
final class ${pascal}ListLoading extends ${pascal}ListState {
  /// 建立載入中狀態。
  const ${pascal}ListLoading();
}

/// 載入成功,攜帶 $pascal 清單。
final class ${pascal}ListLoaded extends ${pascal}ListState {
  /// 以 $pascal 清單建立成功狀態。
  const ${pascal}ListLoaded(this.entries);

  /// $pascal 清單。
  final List<${pascal}Entry> entries;
}

/// 載入失敗,攜帶失敗原因。
final class ${pascal}ListError extends ${pascal}ListState {
  /// 以例外建立失敗狀態。
  const ${pascal}ListError(this.exception);

  /// 失敗原因。
  final AppException exception;
}
''';

String _cubitTemplate({required String name, required String pascal}) =>
    '''
${_imports(['bloc/bloc.dart', '$name/src/domain/repositories/${name}_repository.dart', '$name/src/presentation/blocs/${name}_list/${name}_list_state.dart'])}

/// $pascal 清單頁的 cubit(純 Dart,不 import Flutter)。
///
/// 用 Cubit 而非 Bloc 的理由(conventions §2 第 1 條):目前只有單一觸發
/// 來源——使用者在這個頁面上的操作。**觸發來源變成兩個以上時**(例如改用
/// repository 的 stream 樣板,同時被使用者操作與 stream 推送驅動),或需要
/// `transformer` 做 debounce / droppable,**依判準升級為 Bloc**。那是預期
/// 中的演進,不是設計失誤。
class ${pascal}ListCubit extends Cubit<${pascal}ListState> {
  /// 以 [repository] 建立。
  ${pascal}ListCubit({required ${pascal}Repository repository})
    : _repository = repository,
      super(const ${pascal}ListLoading());

  final ${pascal}Repository _repository;

  /// 載入清單;重試時重複呼叫即可。
  Future<void> load() async {
    emit(const ${pascal}ListLoading());
    final result = await _repository.fetch${pascal}Entries();
    result.fold(
      onSuccess: (entries) => emit(${pascal}ListLoaded(entries)),
      onFailure: (exception) => emit(${pascal}ListError(exception)),
    );
  }
}
''';

String _pageTemplate({required String name, required String pascal}) =>
    '''
${_imports(['dart:async', 'ui/ui.dart', 'flutter/material.dart', 'flutter_bloc/flutter_bloc.dart', 'get_it/get_it.dart', 'localization/localization.dart', '$name/src/presentation/blocs/${name}_list/${name}_list_cubit.dart', '$name/src/presentation/blocs/${name}_list/${name}_list_state.dart'])}

/// $pascal:項目清單。
class ${pascal}Page extends StatelessWidget {
  /// 建立 $pascal 頁。
  const ${pascal}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = context.read<GetIt>()<${pascal}ListCubit>();
        // 進頁面即觸發載入;結果由 state 反映,呼叫端不需要等它。
        unawaited(cubit.load());
        return cubit;
      },
      child: AppPageScaffold(
        // TODO(l10n): 換 feature key
        title: '$pascal',
        body: BlocBuilder<${pascal}ListCubit, ${pascal}ListState>(
          builder: (context, state) {
            return switch (state) {
              ${pascal}ListLoading() => const AppLoadingIndicator(),
              ${pascal}ListError() => AppErrorView(
                message: context.l10n.commonErrorGeneric,
                onRetry: () =>
                    unawaited(context.read<${pascal}ListCubit>().load()),
                retryLabel: context.l10n.commonRetry,
              ),
              ${pascal}ListLoaded(:final entries) when entries.isEmpty =>
                const AppEmptyView(
                  // TODO(l10n): 換 feature key
                  message: '$name is empty',
                ),
              ${pascal}ListLoaded(:final entries) => ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(title: Text(entry.title));
                },
              ),
            };
          },
        ),
      ),
    );
  }
}
''';

String _repositoryImplTestTemplate({
  required String name,
  required String pascal,
}) =>
    '''
${_imports(['flutter_test/flutter_test.dart', 'core/core.dart', '$name/src/data/repositories/${name}_repository_impl.dart', '$name/src/domain/entities/${name}_entry.dart', 'core/testing.dart'])}

const _config = NetworkingConfig(baseUrl: 'https://api.test');

void main() {
  group('${pascal}RepositoryImpl.fetch${pascal}Entries', () {
    test('成功時回傳 Success(List<${pascal}Entry>)(2 筆)', () async {
      final adapter = ScriptedAdapter([
        (_) => jsonResponse(200, \'\'\'
{"entries":[
  {"id":"1","title":"t1"},
  {"id":"2","title":"t2"}
]}
\'\'\'),
      ]);
      final client = ApiClient(
        createPlainDio(config: _config, adapter: adapter),
      );
      final repository = ${pascal}RepositoryImpl(client);

      final result = await repository.fetch${pascal}Entries();

      expect(result, isA<Success<List<${pascal}Entry>>>());
      final entries = (result as Success<List<${pascal}Entry>>).value;
      expect(entries, hasLength(2));
      expect(entries.first.id, '1');
      expect(entries.first.title, 't1');
    });

    test('404 時回傳 Failure(ApiException)', () async {
      final adapter = ScriptedAdapter([(_) => jsonResponse(404, '{}')]);
      final client = ApiClient(
        createPlainDio(config: _config, adapter: adapter),
      );
      final repository = ${pascal}RepositoryImpl(client);

      final result = await repository.fetch${pascal}Entries();

      expect(result, isA<Failure<List<${pascal}Entry>>>());
      expect(
        (result as Failure<List<${pascal}Entry>>).exception,
        isA<ApiException>(),
      );
    });

    test('entries 缺欄位時回傳 Failure(ParsingException)', () async {
      final adapter = ScriptedAdapter([
        (_) => jsonResponse(200, '{"entries":[{"id":"1"}]}'),
      ]);
      final client = ApiClient(
        createPlainDio(config: _config, adapter: adapter),
      );
      final repository = ${pascal}RepositoryImpl(client);

      final result = await repository.fetch${pascal}Entries();

      expect(result, isA<Failure<List<${pascal}Entry>>>());
      expect(
        (result as Failure<List<${pascal}Entry>>).exception,
        isA<ParsingException>(),
      );
    });
  });
}
''';

String _cubitTestTemplate({required String name, required String pascal}) =>
    '''
${_imports(['bloc_test/bloc_test.dart', 'flutter_test/flutter_test.dart', 'core/core.dart', '$name/src/domain/entities/${name}_entry.dart', '$name/src/domain/repositories/${name}_repository.dart', '$name/src/presentation/blocs/${name}_list/${name}_list_cubit.dart', '$name/src/presentation/blocs/${name}_list/${name}_list_state.dart', 'mocktail/mocktail.dart'])}

class _Mock${pascal}Repository extends Mock implements ${pascal}Repository {}

void main() {
  late _Mock${pascal}Repository repository;

  const entries = [
    ${pascal}Entry(id: '1', title: 't1'),
    ${pascal}Entry(id: '2', title: 't2'),
  ];

  setUp(() {
    repository = _Mock${pascal}Repository();
  });

  group('${pascal}ListCubit', () {
    blocTest<${pascal}ListCubit, ${pascal}ListState>(
      '初始狀態為 ${pascal}ListLoading',
      build: () => ${pascal}ListCubit(repository: repository),
      verify: (cubit) {
        expect(cubit.state, isA<${pascal}ListLoading>());
      },
    );

    blocTest<${pascal}ListCubit, ${pascal}ListState>(
      '取得成功 → [${pascal}ListLoaded]',
      setUp: () {
        when(
          () => repository.fetch${pascal}Entries(),
        ).thenAnswer((_) async => const Result.success(entries));
      },
      build: () => ${pascal}ListCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect:
          () => [
            isA<${pascal}ListLoading>(),
            isA<${pascal}ListLoaded>().having(
              (s) => s.entries,
              'entries',
              entries,
            ),
          ],
    );

    blocTest<${pascal}ListCubit, ${pascal}ListState>(
      '取得失敗 → [${pascal}ListError]',
      setUp: () {
        when(() => repository.fetch${pascal}Entries()).thenAnswer(
          (_) async =>
              const Result.failure(ApiException(code: 'E500', message: 'boom')),
        );
      },
      build: () => ${pascal}ListCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect:
          () => [
            isA<${pascal}ListLoading>(),
            isA<${pascal}ListError>().having(
              (s) => s.exception,
              'exception',
              isA<ApiException>(),
            ),
          ],
    );
  });
}
''';

String _pageTestTemplate({required String name, required String pascal}) =>
    '''
${_imports(['flutter/material.dart', 'flutter_bloc/flutter_bloc.dart', 'flutter_test/flutter_test.dart', 'core/core.dart', 'get_it/get_it.dart', '$name/src/domain/entities/${name}_entry.dart', '$name/src/domain/repositories/${name}_repository.dart', '$name/src/presentation/blocs/${name}_list/${name}_list_cubit.dart', '$name/src/presentation/pages/${name}_page.dart', 'localization/localization.dart', 'localization/testing.dart', 'mocktail/mocktail.dart'])}

class _Mock${pascal}Repository extends Mock implements ${pascal}Repository {}

final _l10n = AppLocalizationsEn();

const _entries = [
  ${pascal}Entry(id: '1', title: 't1'),
  ${pascal}Entry(id: '2', title: 't2'),
];

/// 用獨立容器包住待測頁面(見 docs/conventions.md §5 DI 規範)。
Widget _app(GetIt gi) => RepositoryProvider<GetIt>.value(
  value: gi,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ${pascal}Page(),
  ),
);

void main() {
  late _Mock${pascal}Repository repository;
  final gi = GetIt.asNewInstance();

  setUp(() {
    repository = _Mock${pascal}Repository();
    gi.registerFactory<${pascal}ListCubit>(
      () => ${pascal}ListCubit(repository: repository),
    );
  });

  tearDown(() async {
    await gi.reset();
  });

  group('${pascal}Page', () {
    testWidgets('Loading 顯示載入指示', (tester) async {
      when(() => repository.fetch${pascal}Entries()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Result.success(_entries);
      });

      await tester.pumpWidget(_app(gi));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('Error 顯示重試按鈕,點擊後重新發送請求', (tester) async {
      when(() => repository.fetch${pascal}Entries()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return const Result.failure(UnauthorizedException());
      });

      await tester.pumpWidget(_app(gi));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.commonErrorGeneric), findsOneWidget);
      expect(find.text(_l10n.commonRetry), findsOneWidget);

      await tester.tap(find.text(_l10n.commonRetry));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      verify(() => repository.fetch${pascal}Entries()).called(2);
    });

    testWidgets('Loaded 顯示項目清單', (tester) async {
      when(
        () => repository.fetch${pascal}Entries(),
      ).thenAnswer((_) async => const Result.success(_entries));

      await tester.pumpWidget(_app(gi));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.text('t1'), findsOneWidget);
    });

    testWidgets('Loaded 空清單顯示空狀態文案', (tester) async {
      when(
        () => repository.fetch${pascal}Entries(),
      ).thenAnswer((_) async => const Result.success(<${pascal}Entry>[]));

      await tester.pumpWidget(_app(gi));
      await tester.pump();
      await tester.pump();

      expect(find.text('$name is empty'), findsOneWidget);
    });
  });
}
''';

// ---------------------------------------------------------------------------
// 自動接線
// ---------------------------------------------------------------------------

void _wireRootPubspec(String name) {
  const path = 'pubspec.yaml';
  final lines = File(path).readAsLinesSync();
  final featureLineRegex = RegExp(r'^  - features/(.+)$');
  var firstFeatureIdx = -1;
  var lastFeatureIdx = -1;
  for (var i = 0; i < lines.length; i++) {
    if (featureLineRegex.hasMatch(lines[i])) {
      firstFeatureIdx = firstFeatureIdx == -1 ? i : firstFeatureIdx;
      lastFeatureIdx = i;
    }
  }
  var insertAt = lastFeatureIdx + 1;
  for (var i = firstFeatureIdx; i <= lastFeatureIdx; i++) {
    final existingName = featureLineRegex.firstMatch(lines[i])!.group(1)!;
    if (name.compareTo(existingName) < 0) {
      insertAt = i;
      break;
    }
  }
  lines.insert(insertAt, '  - features/$name');
  File(path).writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('✓ 已加入根 pubspec.yaml workspace 清單');
}

void _wireRoutePaths({required String name, required String camel}) {
  const path = 'packages/core/lib/src/navigation/route_paths.dart';
  final content = File(path).readAsStringSync();
  final pascal = _toPascalCase(name);
  final updated = _insertBeforeMarker(
    content,
    '{{route-paths}}',
    (indent) => [
      '$indent/// $pascal。',
      "${indent}static const $camel = '/$name';",
      '',
    ],
  );
  File(path).writeAsStringSync(updated);
  stdout.writeln('✓ 已加入 route_paths.dart 路徑常數');
}

void _wireAppPubspec(String name) {
  const path = 'app/pubspec.yaml';
  final lines = File(path).readAsLinesSync();
  final updated = _insertSortedDependency(lines, name, '$name: any');
  File(path).writeAsStringSync('${updated.join('\n')}\n');
  stdout.writeln('✓ 已加入 app/pubspec.yaml dependencies');
}

void _wireComposeDependencies({required String name, required String pascal}) {
  const path = 'app/lib/src/di/compose_dependencies.dart';
  var content = File(path).readAsStringSync();
  content = _insertSortedImport(content, name);
  content = _insertBeforeMarker(
    content,
    '{{feature-registry}}',
    (indent) => ['${indent}register${pascal}Feature(gi);'],
  );
  File(path).writeAsStringSync(content);
  stdout.writeln('✓ 已加入 compose_dependencies.dart 註冊');
}

void _wireAppRouter({required String name, required String camel}) {
  const path = 'app/lib/src/router/app_router.dart';
  var content = File(path).readAsStringSync();
  content = _insertSortedImport(content, name);
  content = _insertBeforeMarker(
    content,
    '{{feature-registry}}',
    (indent) => ['$indent...${camel}Routes(),'],
  );
  File(path).writeAsStringSync(content);
  stdout.writeln('✓ 已加入 app_router.dart 路由');
}

void _wireDiSmokeTest({required String name, required String pascal}) {
  const path = 'app/test/di_smoke_test.dart';
  var content = File(path).readAsStringSync();
  content = _insertSortedImport(content, name);
  content = _insertBeforeMarker(
    content,
    '{{feature-registry}}',
    (indent) => [
      '${indent}expect(gi<${pascal}Repository>(), isA<${pascal}Repository>());',
      '${indent}expect(gi<${pascal}ListCubit>(), isA<${pascal}ListCubit>());',
    ],
  );
  File(path).writeAsStringSync(content);
  stdout.writeln('✓ 已加入 di_smoke_test.dart 驗證');
}

/// 在含 [markerFragment] 的行之前插入 [buildLines] 產生的內容(保留該行原本
/// 的縮排傳給 [buildLines])。
String _insertBeforeMarker(
  String content,
  String markerFragment,
  List<String> Function(String indent) buildLines,
) {
  final lines = content.split('\n');
  final markerIdx = lines.indexWhere((l) => l.contains(markerFragment));
  if (markerIdx == -1) {
    throw StateError('找不到標記 $markerFragment');
  }
  final indent = RegExp(r'^(\s*)').firstMatch(lines[markerIdx])!.group(1)!;
  lines.insertAll(markerIdx, buildLines(indent));
  return lines.join('\n');
}

/// 在 `import 'package:...';` 連續區塊中依字母序插入新 feature 的 barrel
/// import。
String _insertSortedImport(String content, String name) {
  final lines = content.split('\n');
  final importRegex = RegExp(r"^import 'package:.+';$");
  var firstIdx = -1;
  var lastIdx = -1;
  for (var i = 0; i < lines.length; i++) {
    if (importRegex.hasMatch(lines[i])) {
      firstIdx = firstIdx == -1 ? i : firstIdx;
      lastIdx = i;
    }
  }
  final newImport = "import 'package:$name/$name.dart';";
  var insertAt = lastIdx + 1;
  for (var i = firstIdx; i <= lastIdx; i++) {
    if (newImport.compareTo(lines[i]) < 0) {
      insertAt = i;
      break;
    }
  }
  lines.insert(insertAt, newImport);
  return lines.join('\n');
}

/// 在 pubspec `dependencies:` 區塊(至 `dev_dependencies:` 或區塊結束為止)
/// 依 key 字母序插入新項目;每個既有項目可能跨多行(如 `flutter:` 巢狀
/// `sdk: flutter`),以下一個頂層 key(2 格縮排)界定範圍。
List<String> _insertSortedDependency(
  List<String> lines,
  String key,
  String newEntryLine,
) {
  final depStart = lines.indexOf('dependencies:') + 1;
  var depEnd = lines.indexOf('dev_dependencies:', depStart);
  if (depEnd == -1) {
    depEnd = lines.length;
  }

  final entryRegex = RegExp(r'^  (\S+):');
  final entries = <MapEntry<String, List<String>>>[];
  var i = depStart;
  while (i < depEnd) {
    final match = entryRegex.firstMatch(lines[i]);
    if (match == null) {
      i++;
      continue;
    }
    final entryKey = match.group(1)!;
    final entryLines = [lines[i]];
    var j = i + 1;
    while (j < depEnd && !entryRegex.hasMatch(lines[j])) {
      entryLines.add(lines[j]);
      j++;
    }
    entries.add(MapEntry(entryKey, entryLines));
    i = j;
  }

  var insertAt = entries.length;
  for (var k = 0; k < entries.length; k++) {
    if (key.compareTo(entries[k].key) < 0) {
      insertAt = k;
      break;
    }
  }
  entries.insert(insertAt, MapEntry(key, ['  $newEntryLine']));

  final rebuilt = entries.expand((e) => e.value).toList();
  return [...lines.sublist(0, depStart), ...rebuilt, ...lines.sublist(depEnd)];
}

void _printNextSteps({
  required String name,
  required String pascal,
  required String camel,
}) {
  stdout
    ..writeln()
    ..writeln('✓ features/$name 已建立並完成接線。後續步驟:')
    ..writeln('  1. l10n:於 packages/localization 的 ARB 加入 $camel 前綴')
    ..writeln('     的 key(如 ${camel}Title、${camel}Empty),取代 ${pascal}Page 內的')
    ..writeln('     暫用字串與 // TODO(l10n) 註解,並 gen-l10n 重新產生。')
    ..writeln('  2. API:將 ${pascal}RepositoryImpl 的 GET /$name/entries 換成真實')
    ..writeln('     後端路徑與欄位(視需要調整 ${pascal}EntryDto)。')
    ..writeln('  3. 若清單項目需要導向詳情頁,於本 feature 的 lib/src/routes.dart 補上型別化')
    ..writeln('     route 類別(如 ${pascal}DetailRoute),並在 routes.dart 加入巢狀')
    ..writeln('     GoRoute(參考 features/home 的 items/:id)。')
    ..writeln('  4. 若此 feature 需在底部導覽列顯示,於 app 的 shell(AppShell)加入')
    ..writeln('     分頁項目並導向 RoutePaths.$camel。')
    ..writeln('  5. 執行 ./tool/check.sh 確認全綠。');
}
