// 由 pubspec 產生 docs/architecture.md 的三個事實區塊。
//
// 手寫的事實保證會漂移:加一個 package、改一條依賴、刪一個成員,文件不會
// 自己跟上,而 CI 完全不會發現。對 AI agent 特別致命——它讀了過期的依賴表
// 就照過期的規則寫 code,被 check.sh 擋下來後再回頭猜原因。
//
// 用法:
//   fvm dart run tool/gen_arch_docs.dart           寫回 architecture.md
//   fvm dart run tool/gen_arch_docs.dart --check    只比對,有差異 exit 1
//
// 只產生「從 pubspec 算得出來的事實」。§3 那些是判斷與敘述,人寫的才有價值。
import 'dart:io';

const _docPath = 'docs/architecture.md';

void main(List<String> args) {
  final checkOnly = args.contains('--check');
  final members = _readWorkspaceMembers();
  final names = {for (final m in members) m.name};

  final replacements = {
    'workspace-list': _renderWorkspaceList(members),
    'member-count': _renderMemberCount(members),
    'topology': _renderTopology(members),
    'dependency-table': _renderDependencyTable(members, names),
    'dependency-graph': _renderDependencyGraph(members, names),
  };

  final file = File(_docPath);
  final original = file.readAsStringSync();
  var updated = original;
  for (final entry in replacements.entries) {
    updated = _replaceBlock(updated, entry.key, entry.value);
  }

  if (updated == original) {
    stdout.writeln('✓ 架構文件已與 pubspec 同步');
    return;
  }
  if (checkOnly) {
    stderr.writeln('✗ $_docPath 與 pubspec 不一致,以下區塊需要 regen:');
    for (final key in replacements.keys) {
      if (_blockOf(original, key) != replacements[key]) {
        stderr.writeln('  - $key');
      }
    }
    exit(1);
  }
  file.writeAsStringSync(updated);
  stdout.writeln('✓ 已更新 $_docPath');
}

/// 一個 workspace 成員的最小事實。
class _Member {
  _Member({
    required this.path,
    required this.name,
    required this.description,
    required this.dependencies,
  });

  final String path;
  final String name;
  final String description;
  final List<String> dependencies;
}

List<_Member> _readWorkspaceMembers() {
  final root = File('pubspec.yaml').readAsLinesSync();
  final paths = <String>[];
  var inWorkspace = false;
  for (final line in root) {
    if (line.startsWith('workspace:')) {
      inWorkspace = true;
      continue;
    }
    if (inWorkspace) {
      if (line.startsWith('  - ')) {
        paths.add(line.substring(4).trim());
      } else if (line.trim().isNotEmpty && !line.startsWith(' ')) {
        break;
      }
    }
  }
  // 順序固定為 workspace 清單順序;排序不固定會產生假 diff。
  return paths.map(_readMember).toList();
}

_Member _readMember(String path) {
  final lines = File('$path/pubspec.yaml').readAsLinesSync();
  var name = '';
  var description = '';
  final deps = <String>[];
  var inDeps = false;
  for (final line in lines) {
    if (line.startsWith('name:')) {
      name = line.substring(5).trim();
    } else if (line.startsWith('description:')) {
      description = line.substring(12).trim();
    } else if (line.startsWith('dependencies:')) {
      inDeps = true;
      continue;
    } else if (line.isNotEmpty && !line.startsWith(' ')) {
      inDeps = false;
    }
    if (inDeps && line.startsWith('  ') && !line.startsWith('    ')) {
      final key = line.trim().split(':').first;
      if (key.isNotEmpty) {
        deps.add(key);
      }
    }
  }
  return _Member(
    path: path,
    name: name,
    description: description,
    dependencies: deps,
  );
}

/// 依賴屬於 workspace 成員的判斷:名稱出現在成員的 name 集合裡即算。
///
/// 刻意不用 `any` 這個版本字串判斷——未來可能改成路徑依賴。
List<String> _workspaceDepsOf(_Member m, Set<String> names) =>
    m.dependencies.where(names.contains).toList()..sort();

/// 根 pubspec 的 `workspace:` 清單原文。
///
/// 這段原本是手抄的,收斂為 8 個成員時漏抄了 `packages/permissions`,而
/// 漂移檢查只看 GENERATED 區塊、抓不到區塊外的散文。
String _renderWorkspaceList(List<_Member> members) {
  final buffer = StringBuffer()
    ..writeln('```yaml')
    ..writeln('workspace:');
  for (final m in members) {
    buffer.writeln('  - ${m.path}');
  }
  buffer.writeln('```');
  return buffer.toString().trimRight();
}

/// 「N 個成員 = 1 個 app + M 個 packages + K 個 features」。
///
/// 同樣是手寫必漂的事實:成員數改了沒人會記得回來改這句。
String _renderMemberCount(List<_Member> members) {
  final packages = members.where((m) => m.path.startsWith('packages/')).length;
  final features = members.where((m) => m.path.startsWith('features/')).length;
  final apps = members.length - packages - features;
  return '${members.length} 個成員 = $apps 個 `app` + $packages 個 '
      '`packages/*` + $features 個 `features/*`';
}

String _renderTopology(List<_Member> members) {
  final buffer = StringBuffer()
    ..writeln('| 成員 | 職責(一句話) |')
    ..writeln('|---|---|');
  for (final m in members) {
    buffer.writeln(
      '| `${m.path}` | ${m.description} '
      '([`${m.path}/pubspec.yaml`](../${m.path}/pubspec.yaml)) |',
    );
  }
  return buffer.toString().trimRight();
}

String _renderDependencyTable(List<_Member> members, Set<String> names) {
  final buffer = StringBuffer()
    ..writeln('| 成員 | 依賴的 workspace 成員 |')
    ..writeln('|---|---|');
  for (final m in members) {
    final deps = _workspaceDepsOf(m, names);
    final rendered = deps.isEmpty ? '(無)' : deps.map((d) => '`$d`').join('、');
    buffer.writeln('| `${m.path}` | $rendered |');
  }
  return buffer.toString().trimRight();
}

String _renderDependencyGraph(List<_Member> members, Set<String> names) {
  final buffer = StringBuffer()
    ..writeln('```mermaid')
    ..writeln('graph TD');
  // 節點宣告一次(帶斜線的名稱要用 `auth[features/auth]` 的形式標註完整
  // 路徑),邊只用 id——同一個標籤重複寫在每條邊上會讓圖很難讀。
  for (final m in members) {
    buffer.writeln(
      m.path.contains('/') ? '  ${m.name}[${m.path}]' : '  ${m.name}',
    );
  }
  buffer.writeln();
  for (final m in members) {
    for (final dep in _workspaceDepsOf(m, names)) {
      buffer.writeln('  ${m.name} --> $dep');
    }
  }
  buffer.write('```');
  return buffer.toString();
}

String _beginMark(String key) => '<!-- BEGIN GENERATED: $key -->';
String _endMark(String key) => '<!-- END GENERATED: $key -->';

String? _blockOf(String doc, String key) {
  final start = doc.indexOf(_beginMark(key));
  final end = doc.indexOf(_endMark(key));
  if (start < 0 || end < 0) {
    return null;
  }
  return doc.substring(start + _beginMark(key).length, end).trim();
}

String _replaceBlock(String doc, String key, String content) {
  final begin = _beginMark(key);
  final end = _endMark(key);
  final start = doc.indexOf(begin);
  final stop = doc.indexOf(end);
  if (start < 0 || stop < 0) {
    stderr.writeln('✗ $_docPath 缺少 $key 的 GENERATED 標記');
    exit(1);
  }
  return doc.replaceRange(start + begin.length, stop, '\n$content\n');
}
