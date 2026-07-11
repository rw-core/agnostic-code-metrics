import 'dart:io';

import 'git.dart';
import 'metrics.dart';

/// Per-file result: head metrics plus, when the file existed at base, the base
/// metrics and their delta.
class FileReport {
  const FileReport({
    required this.path,
    required this.status,
    required this.head,
    required this.base,
    required this.delta,
  });

  final String path;
  final ChangeStatus status;
  final Metrics head;
  final Metrics? base;
  final Metrics? delta;
}

/// Runs the lexical metrics engine over each changed file. Files that throw
/// (binary, unparseable) are skipped rather than failing the whole run.
List<FileReport> analyze(List<ChangedFile> files) {
  final reports = <FileReport>[];
  for (final f in files) {
    try {
      final head = Metrics.compute(f.path, f.headSource);
      final base = f.baseSource == null
          ? null
          : Metrics.compute(f.path, f.baseSource!);
      reports.add(FileReport(
        path: f.path,
        status: f.status,
        head: head,
        base: base,
        delta: base == null ? null : head - base,
      ));
    } catch (e) {
      stderr.writeln('agnostic-code-metrics: skipped ${f.path}: $e');
    }
  }
  return reports;
}
