import 'dart:convert';
import 'dart:io';

/// The change status of a file within the PR diff.
enum ChangeStatus { added, modified, renamed }

/// A single changed file in the PR, plus its source at base and head.
class ChangedFile {
  const ChangedFile({
    required this.path,
    required this.status,
    required this.headSource,
    required this.baseSource,
  });

  final String path;
  final ChangeStatus status;
  final String headSource;

  /// Null when the file did not exist at base (i.e. [ChangeStatus.added]).
  final String? baseSource;
}

/// Reads the PR diff from the git checkout in [repoRoot].
class GitRepo {
  GitRepo(this.repoRoot);

  final String repoRoot;

  /// Extracts base/head SHAs from the GitHub event payload at
  /// `GITHUB_EVENT_PATH`. Returns null when the event is not a pull request.
  static ({String base, String head})? readPrShas(String? eventPath) {
    if (eventPath == null || eventPath.isEmpty) return null;
    final file = File(eventPath);
    if (!file.existsSync()) return null;
    final payload = jsonDecode(file.readAsStringSync());
    if (payload is! Map || payload['pull_request'] is! Map) return null;
    final pr = payload['pull_request'] as Map;
    final base = (pr['base'] as Map?)?['sha'] as String?;
    final head = (pr['head'] as Map?)?['sha'] as String?;
    if (base == null || head == null) return null;
    return (base: base, head: head);
  }

  /// Returns the changed files between [base] and [head] using the merge-base
  /// (three-dot) diff, restricted by [include]/[exclude] globs and to
  /// recognised source extensions. Deleted files are omitted.
  List<ChangedFile> changedFiles({
    required String base,
    required String head,
    required List<String> include,
    required List<String> exclude,
  }) {
    final raw = _git(['diff', '--name-status', '-M', '$base...$head']);
    final result = <ChangedFile>[];

    for (final line in const LineSplitter().convert(raw)) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\t');
      final code = parts.first;
      // For renames git emits `R<score>\told\tnew`; the current path is last.
      final path = parts.last;

      final status = switch (code[0]) {
        'A' => ChangeStatus.added,
        'M' => ChangeStatus.modified,
        'R' => ChangeStatus.renamed,
        _ => null, // D (deleted), C (copied), T (type change) → skip
      };
      if (status == null) continue;
      if (!isSourceFile(path)) continue;
      if (!matches(path, include: include, exclude: exclude)) continue;

      final headSource = _show(head, path);
      if (headSource == null) continue;
      final baseSource =
          status == ChangeStatus.added ? null : _show(base, path);

      result.add(ChangedFile(
        path: path,
        status: status,
        headSource: headSource,
        baseSource: baseSource,
      ));
    }
    return result;
  }

  /// Reads a blob at `<ref>:<path>`, or null if it cannot be read.
  String? _show(String ref, String path) {
    final r = Process.runSync('git', ['show', '$ref:$path'],
        workingDirectory: repoRoot, stdoutEncoding: utf8, stderrEncoding: utf8);
    return r.exitCode == 0 ? r.stdout as String : null;
  }

  String _git(List<String> args) {
    final r = Process.runSync('git', args,
        workingDirectory: repoRoot, stdoutEncoding: utf8, stderrEncoding: utf8);
    if (r.exitCode != 0) {
      throw StateError('git ${args.join(' ')} failed: ${r.stderr}');
    }
    return r.stdout as String;
  }

  /// File extensions the lexical engine can meaningfully analyse.
  static const sourceExtensions = <String>{
    'dart',
    'js',
    'jsx',
    'ts',
    'tsx',
    'py',
    'java',
    'kt',
    'kts',
    'go',
    'rs',
    'rb',
    'php',
    'c',
    'h',
    'cc',
    'cpp',
    'cxx',
    'hpp',
    'cs',
    'swift',
    'scala',
    'm',
    'mm',
    'sh',
    'bash',
    'lua',
    'groovy',
    'sql',
    'vue',
    'svelte',
  };

  static bool isSourceFile(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    return sourceExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  /// Applies include (if any) then exclude glob lists. Empty include ⇒ all.
  static bool matches(String path,
      {required List<String> include, required List<String> exclude}) {
    if (include.isNotEmpty && !include.any((g) => _globMatch(g, path))) {
      return false;
    }
    if (exclude.any((g) => _globMatch(g, path))) return false;
    return true;
  }

  static final _cache = <String, RegExp>{};

  static bool _globMatch(String glob, String path) {
    final re =
        _cache.putIfAbsent(glob, () => RegExp('^${_globToRegex(glob)}\$'));
    return re.hasMatch(path);
  }

  /// Translates a glob (`**`, `*`, `?`) into a regular expression.
  static String _globToRegex(String glob) {
    final sb = StringBuffer();
    for (var i = 0; i < glob.length; i++) {
      final c = glob[i];
      switch (c) {
        case '*':
          if (i + 1 < glob.length && glob[i + 1] == '*') {
            sb.write('.*');
            i++;
          } else {
            sb.write('[^/]*');
          }
        case '?':
          sb.write('[^/]');
        case '.':
        case '(':
        case ')':
        case '+':
        case '|':
        case '^':
        case r'$':
        case '@':
        case '%':
        case '{':
        case '}':
        case '[':
        case ']':
        case r'\':
          sb.write('\\$c');
        default:
          sb.write(c);
      }
    }
    return sb.toString();
  }
}
