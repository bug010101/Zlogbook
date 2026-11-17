import 'package:flutter/material.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/widgets/common.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: <Widget>[
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Z',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              AppInfo.name,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '${AppInfo.tagline} · ${AppInfo.version}',
              style: TextStyle(fontSize: 12, color: kInkSoft),
            ),
          ),
          const SizedBox(height: 26),
          const SectionCard(
            title: '数据在哪',
            children: <Widget>[
              Text(
                '所有记录存在本机一个 SQLite 文件里，应用私有目录，其他应用读不到。\n'
                '不联网、不上传、不加密，也不需要登录。\n'
                '卸载应用等于删除数据，请定期导出备份。',
                style: TextStyle(fontSize: 13, height: 1.7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: '能带走什么',
            children: <Widget>[
              Text(
                '任意时刻可以导出 zip：records.csv、identities.csv、folders.csv、'
                'field_defs.csv、meta.json。\n'
                '用 Excel / WPS / 文本编辑器都能打开，也可以再导回本软件。',
                style: TextStyle(fontSize: 13, height: 1.7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: '不做什么',
            children: <Widget>[
              Text(
                '不做账号体系、不做云同步、不做多设备、不存密码、不做统计图表、'
                '不发系统通知。\n'
                '目标只有一个：记清楚你有什么账号、用什么方式登录。',
                style: TextStyle(fontSize: 13, height: 1.7),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
