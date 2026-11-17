import 'package:flutter/material.dart';
import 'package:zlogbook/core/csv_columns.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/services/export_service.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';

/// 全屏的 CSV 格式说明。表格内容全部由列名常量生成，与解析逻辑同源。
class CsvFormatPanel extends StatelessWidget {
  const CsvFormatPanel({super.key});

  static const List<List<String>> _pitfalls = <List<String>>[
    <String>[
      '未识别的列会当成自定义字段',
      '列名就是字段名，可以随便加列，导入后自动建字段',
    ],
    <String>[
      'Excel 另存 CSV 编码要选 UTF-8',
      '选成 GBK 会乱码，中文全变问号',
    ],
    <String>[
      '日期只认 2026-12-01',
      '2026/12/1、2026年12月1日 会被跳过',
    ],
  ];

  static const List<List<String>> _comparisons = <List<String>>[
    <String>['2026/12/1', '2026-12-01'],
    <String>['¥99', '99'],
    <String>['常用,有余额', '常用|有余额'],
    <String>['备注带逗号不加引号', '"这里,有逗号"'],
    <String>['把手机号填进 id', 'id 留空'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV 格式怎么写'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: <Widget>[
          _title('① 最快的方法'),
          const Text(
            '先在本软件里导出一份，照样子改，再导回来。\n'
            '导出的文件天然合规：列名、顺序、引号转义全是对的。',
            style: TextStyle(fontSize: 13, color: kInkSoft, height: 1.7),
          ),
          _title('② 最小可用示例'),
          _codeBlock(
            kCsvMinimalExampleRows
                .map((List<String> row) => row.join(','))
                .join('\n'),
          ),
          const SizedBox(height: 6),
          const Text(
            '只有 name 是必填。其余列可以整列不要。',
            style: TextStyle(fontSize: 12, color: kInkSoft),
          ),
          _title('③ 完整列说明'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < kRecordCsvColumnSpecs.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    _columnRow(kRecordCsvColumnSpecs[i]),
                  ],
                ],
              ),
            ),
          ),
          _title('④ 三个坑'),
          for (final List<String> item in _pitfalls)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(Icons.circle, size: 5, color: kInkSoft),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item[0],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          item[1],
                          style: const TextStyle(
                            fontSize: 12,
                            color: kInkSoft,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          _title('⑤ 对照表'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: <Widget>[
                  Row(
                    children: const <Widget>[
                      SizedBox(
                        width: 130,
                        child: Text(
                          '写错',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kInkSoft,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '写对',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kInkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final List<String> pair in _comparisons)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 130,
                            child: Text(
                              pair[0],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFA85A50),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              pair[1],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF3E7B5C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '降低门槛的核心规则：列名认不出来的一律当自定义字段。\n'
              '你在 Excel 里随手加的列（游戏段位、月租、注册渠道），'
              '导入后会自动变成自定义字段，出现在编辑页。\n'
              '新字段一律按文本类型创建，需要时去「设置 → 自定义字段」改类型。',
              style: TextStyle(fontSize: 12.5, color: kInk, height: 1.7),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () async {
                try {
                  await ExportService.shareTemplate();
                } catch (error) {
                  if (context.mounted) {
                    showToast(context, '模板生成失败：$error');
                  }
                }
              },
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('下载模板'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _codeBlock(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2F2C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          content,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.7,
            color: Color(0xFFE8E6DF),
          ),
        ),
      ),
    );
  }

  Widget _columnRow(CsvColumnSpec spec) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                spec.name,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (spec.required) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA85A50).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '必填',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8C463D),
                    ),
                  ),
                ),
              ],
              if (spec.type.isNotEmpty) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  spec.type,
                  style: const TextStyle(fontSize: 11, color: kInkSoft),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            spec.example.isEmpty
                ? spec.description
                : '${spec.description}　例：${spec.example}',
            style: const TextStyle(fontSize: 12, color: kInkSoft, height: 1.45),
          ),
        ],
      ),
    );
  }
}
