import 'dart:io';

/// Parsed action configuration, sourced from `INPUT_*` environment variables
/// that the composite `action.yml` sets from the action inputs.
class Config {
  const Config({
    required this.token,
    required this.workspace,
    required this.include,
    required this.exclude,
    required this.thresholds,
    required this.failOnViolation,
    required this.comment,
  });

  final String token;

  /// Absolute path to the repository being analysed (the consumer's checkout).
  final String workspace;

  final List<String> include;
  final List<String> exclude;

  /// Threshold value per metric key (see [Thresholds] keys). Unset ⇒ absent.
  final Map<String, double> thresholds;

  final bool failOnViolation;
  final bool comment;

  static Config fromEnvironment([Map<String, String>? source]) {
    final env = source ?? Platform.environment;

    final workspace = _str(env, 'GITHUB_WORKSPACE') ?? Directory.current.path;
    final workingDir = _str(env, 'INPUT_WORKING_DIRECTORY') ?? '.';
    final repoRoot = _resolve(workspace, workingDir);

    return Config(
      token: _str(env, 'INPUT_GITHUB_TOKEN') ?? '',
      workspace: repoRoot,
      include: _list(env, 'INPUT_INCLUDE', _defaultInclude),
      exclude: _list(env, 'INPUT_EXCLUDE', _defaultExclude),
      thresholds: {
        for (final key in _thresholdKeys.keys)
          if (_num(env, _thresholdKeys[key]!) case final double v) key: v,
      },
      failOnViolation: _bool(env, 'INPUT_FAIL_ON_VIOLATION'),
      comment: _bool(env, 'INPUT_COMMENT', defaultValue: true),
    );
  }

  static const _thresholdKeys = <String, String>{
    'cyclomatic': 'INPUT_MAX_CYCLOMATIC',
    'cognitive': 'INPUT_MAX_COGNITIVE',
    'npath': 'INPUT_MAX_NPATH',
    'abc': 'INPUT_MAX_ABC',
    'halsteadBugs': 'INPUT_MAX_HALSTEAD_BUGS',
    'maintainability': 'INPUT_MIN_MAINTAINABILITY',
  };

  static const _defaultInclude = <String>[];
  static const _defaultExclude = <String>[
    '**/*.g.dart',
    '**/*.freezed.dart',
    '**/test/**',
    '**/tests/**',
    '**/*.min.js',
  ];

  static String? _str(Map<String, String> env, String key) {
    final v = env[key]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static double? _num(Map<String, String> env, String key) {
    final v = _str(env, key);
    return v == null ? null : double.tryParse(v);
  }

  static bool _bool(Map<String, String> env, String key,
      {bool defaultValue = false}) {
    final v = _str(env, key)?.toLowerCase();
    if (v == null) return defaultValue;
    return v == 'true' || v == '1' || v == 'yes';
  }

  static List<String> _list(
      Map<String, String> env, String key, List<String> fallback) {
    final v = _str(env, key);
    if (v == null) return fallback;
    final items = v
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return items.isEmpty ? fallback : items;
  }

  static String _resolve(String base, String rel) {
    if (rel == '.' || rel.isEmpty) return base;
    if (rel.startsWith('/')) return rel;
    return '$base/$rel';
  }
}
