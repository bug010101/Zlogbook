import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/data/csv/import_plan.dart';
import 'package:zlogbook/data/csv/import_writer.dart';
import 'package:zlogbook/data/csv/ledger_parser.dart';
import 'package:zlogbook/pages/settings/csv_format_panel.dart';
import 'package:zlogbook/services/import_service.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';

/// 导入四步：选文件 -> 预览 -> 选策略 -> 确认写入（写入前自动快照）。
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  ParsedImport? _source;
  ImportPlan? _plan;
  ImportStrategy _strategy = ImportStrategy.overwrite;
  ImportOutcome? _outcome;
  String? _error;
  bool _busy = false;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ParsedImport? source = await ImportService.pickAndParse();
      if (!mounted) {
        return;
      }
      if (source == null) {
        setState(() => _busy = false);
        return;
      }
      final ImportPlan plan =
          ImportService.buildPlan(source, AppScope.read(context));
      setState(() {
        _source = source;
        _plan = plan;
        _outcome = null;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  Future<void> _apply() async {
    final ImportPlan? plan = _plan;
    final ParsedImport? source = _source;
    if (plan == null || source == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ImportOutcome outcome = await ImportService.apply(
        plan: plan,
        strategy: _strategy,
        source: source,
      );
      if (!mounted) {
        return;
      }
      await AppScope.read(context).reloadAll();
      if (!mounted) {
        return;
      }
      setState(() {
        _outcome = outcome;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _source = null;
      _plan = null;
      _outcome = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          if (_error != null) ...<Widget>[
            Card(
              color: const Color(0xFFFBEFEC),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Color(0xFFA85A50),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8C463D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _outcome != null
              ? _resultCard()
              : (_plan == null
                  ? _emptyCard()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _previewBlocks(_plan!),
                    )),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CsvFormatPanel(),
                ),
              ),
              icon: const Icon(Icons.help_outline, size: 16),
              label: const Text('CSV 格式怎么写'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '导入记录',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '支持本软件导出的 zip 包，也支持自己写的 .csv。\n'
              '写入前会先做一次数据库快照，出问题可以在设置页的回滚点恢复。',
              style: TextStyle(fontSize: 13, color: kInkSoft, height: 1.6),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.file_open_outlined, size: 18),
                label: Text(_busy ? '解析中…' : '选择文件'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _previewBlocks(ImportPlan plan) {
    final ParsedImport? source = _source;
    return <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              const Icon(Icons.description_outlined, size: 20, color: kAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      source?.sourceName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '共 ${source?.dataRowCount ?? 0} 行数据'
                      '${plan.skippedRows > 0 ? '，${plan.skippedRows} 行被跳过' : ''}',
                      style: const TextStyle(fontSize: 12, color: kInkSoft),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _reset, child: const Text('重选')),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: '预览',
        children: <Widget>[
          Row(
            children: <Widget>[
              _stat('新增', plan.createCount, const Color(0xFF3E7B5C)),
              _stat('更新', plan.updateCount, kAccent),
              _stat('未变化', plan.unchangedCount, kInkSoft),
              _stat('冲突', plan.conflictCount, const Color(0xFFA85A50)),
            ],
          ),
          if (plan.newFieldLabels.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _hint(
              '将新建 ${plan.newFieldLabels.length} 个自定义字段：'
              '${plan.newFieldLabels.take(6).join('、')}'
              '${plan.newFieldLabels.length > 6 ? ' 等' : ''}',
            ),
          ],
          if (plan.newFolderNames.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            _hint('将新建文件夹：${plan.newFolderNames.join('、')}'),
          ],
          if (plan.warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final String warning in plan.warnings.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '· $warning',
                  style: const TextStyle(fontSize: 12, color: kInkSoft),
                ),
              ),
            if (plan.warnings.length > 6)
              Text(
                '· 还有 ${plan.warnings.length - 6} 条提示',
                style: const TextStyle(fontSize: 12, color: kInkSoft),
              ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: '冲突策略',
        children: <Widget>[
          for (final ImportStrategy strategy in ImportStrategy.values)
            _strategyRow(strategy),
        ],
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: _busy || !plan.hasWork ? null : _apply,
          child: Text(_busy ? '写入中…' : '开始导入'),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '写入前会自动保存一份数据库快照。',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: kInkSoft),
      ),
    ];
  }

  Widget _strategyRow(ImportStrategy strategy) {
    final bool selected = _strategy == strategy;
    return InkWell(
      onTap: () => setState(() => _strategy = strategy),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? kAccent : kLine,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strategy.label,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    strategy.description,
                    style: const TextStyle(fontSize: 11, color: kInkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard() {
    final ImportOutcome outcome = _outcome!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.check_circle, color: Color(0xFF3E7B5C)),
                const SizedBox(width: 8),
                Text(
                  '导入完成',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              outcome.summary,
              style: const TextStyle(fontSize: 13, color: kInkSoft, height: 1.6),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('再导入一次'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: kInkSoft),
          ),
        ],
      ),
    );
  }

  Widget _hint(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: kInkSoft, height: 1.5),
    );
  }
}
