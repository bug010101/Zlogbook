import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/login_method.dart';
import 'package:zlogbook/models/record.dart';

/// 冲突策略：跳过 / 覆盖 / 全部新建。
enum ImportStrategy { skip, overwrite, createNew }

const List<String> _strategyLabels = <String>['跳过冲突项', '覆盖已有记录', '全部新建'];

extension ImportStrategyX on ImportStrategy {
  String get label => _strategyLabels[index];

  String get description {
    switch (this) {
      case ImportStrategy.skip:
        return 'id 相同的记录保持原样';
      case ImportStrategy.overwrite:
        return 'id 相同的记录用文件内容覆盖';
      case ImportStrategy.createNew:
        return 'id 相同的记录另存为一条新记录';
    }
  }
}

/// 单行的处理结果。
enum ImportRowState { create, update, unchanged, duplicate }

/// 已解析好的一行：不含 id 与文件夹 id，落库时补齐。
class ImportCandidate {
  const ImportCandidate({
    required this.line,
    required this.name,
    required this.status,
    required this.importance,
    required this.tags,
    required this.logins,
    required this.extra,
    required this.createdAt,
    this.targetId,
    this.desiredId,
    this.folderName,
    this.notes,
    this.url,
    this.value,
    this.expiresAt,
    this.state = ImportRowState.create,
  });

  final int line;
  final String name;
  final RecordStatus status;
  final int importance;
  final List<String> tags;
  final List<LoginMethod> logins;
  final Map<String, Object?> extra;
  final DateTime createdAt;

  /// 命中的已有记录 id，为空表示新建。
  final String? targetId;

  /// 文件里写了 id 但库里不存在时，新建记录沿用这个 id。
  final String? desiredId;
  final String? folderName;
  final String? notes;
  final String? url;
  final double? value;
  final DateTime? expiresAt;
  final ImportRowState state;

  ImportCandidate withState(ImportRowState next) {
    return ImportCandidate(
      line: line,
      name: name,
      status: status,
      importance: importance,
      tags: tags,
      logins: logins,
      extra: extra,
      createdAt: createdAt,
      targetId: targetId,
      desiredId: desiredId,
      folderName: folderName,
      notes: notes,
      url: url,
      value: value,
      expiresAt: expiresAt,
      state: next,
    );
  }

  AssetRecord build({
    required String id,
    required String? folderId,
    required DateTime now,
  }) {
    return AssetRecord(
      id: id,
      name: name,
      folderId: folderId,
      status: status,
      importance: importance,
      notes: notes,
      url: url,
      value: value,
      expiresAt: expiresAt,
      tags: tags,
      logins: logins,
      extra: extra,
      createdAt: createdAt,
      updatedAt: now,
    );
  }
}

class ImportPlan {
  const ImportPlan({
    required this.candidates,
    required this.newFieldLabels,
    required this.newFolderNames,
    required this.warnings,
    required this.skippedRows,
  });

  final List<ImportCandidate> candidates;
  final List<String> newFieldLabels;
  final List<String> newFolderNames;
  final List<String> warnings;
  final int skippedRows;

  int get createCount => candidates
      .where((ImportCandidate c) => c.state == ImportRowState.create)
      .length;

  int get updateCount => candidates
      .where((ImportCandidate c) => c.state == ImportRowState.update)
      .length;

  int get unchangedCount => candidates
      .where((ImportCandidate c) => c.state == ImportRowState.unchanged)
      .length;

  int get conflictCount => candidates
      .where((ImportCandidate c) => c.state == ImportRowState.duplicate)
      .length;

  int get totalRows => candidates.length + skippedRows;

  bool get hasWork => createCount + updateCount + conflictCount > 0;
}
