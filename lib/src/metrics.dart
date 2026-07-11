import 'package:rw_git/rw_git.dart';

/// The six lexical metrics computed for a single source file, decoupled from
/// the `rw_git` DTO so the rest of the code (report, thresholds, tests) does
/// not depend on the shape of the upstream type.
class Metrics {
  const Metrics({
    required this.cyclomatic,
    required this.cognitive,
    required this.maintainability,
    required this.halsteadBugs,
    required this.abc,
    required this.npath,
  });

  final double cyclomatic;
  final double cognitive;
  final double maintainability;
  final double halsteadBugs;
  final double abc;
  final double npath;

  /// Runs the file's source through the `rw_git` lexical metrics engine.
  ///
  /// Uses the synchronous [LexicalMetricsRunner] facade (Option 1) which
  /// returns every metric in a single call.
  static Metrics compute(String path, String source) {
    final dto = LexicalMetricsRunner.execute(path, source);
    return Metrics(
      cyclomatic: _asDouble(dto.cyclomaticComplexity),
      cognitive: _asDouble(dto.cognitiveComplexity),
      maintainability: _asDouble(dto.maintainabilityIndex),
      halsteadBugs: _asDouble(dto.halsteadDeliveredBugs),
      abc: _asDouble(dto.abcScore),
      npath: _asDouble(dto.npathComplexity),
    );
  }

  /// Per-metric delta `this - other`. Used to show whether a PR made a file
  /// better or worse relative to its base revision.
  Metrics operator -(Metrics other) => Metrics(
        cyclomatic: cyclomatic - other.cyclomatic,
        cognitive: cognitive - other.cognitive,
        maintainability: maintainability - other.maintainability,
        halsteadBugs: halsteadBugs - other.halsteadBugs,
        abc: abc - other.abc,
        npath: npath - other.npath,
      );

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
