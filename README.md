# Zlogbook

纯本地的个人数字资产台账。记下你有什么账号、每个用什么方式登录，随时查得到、筛得出、导得走。

- 单人使用、纯本地、不联网、打开即用、数据自己能拿走
- 不做账号体系、不做主密码、不做应用锁，不存密码、不需要加密
- 所有数据在一个 SQLite 文件里，删除应用即彻底消失

## 仓库里有什么

```
lib/
├── main.dart                 入口：初始化数据库工厂、加载数据、启动 UI
├── app.dart                  MaterialApp、主题、启动失败兜底页
├── core/                     与业务无关的横切能力
│   ├── app_info.dart         应用常量、偏好键
│   ├── csv_columns.dart      CSV 列名单一事实来源（解析 / 导出 / 说明面板共用）
│   ├── theme.dart            浅色主题与配色
│   └── utils/                时间、文本、UUID
├── models/                   数据模型（enums / record / login_method / …）
├── repositories/             领域层仓储接口，页面只依赖接口
├── data/
│   ├── db/                   连接、建表、快照
│   ├── dao/                  纯 SQL，返回原始行
│   ├── repositories/         仓储实现：行 ↔ 模型映射
│   └── csv/                  CSV 编解码、导出打包、解析、预览计划、落库
├── state/                    AppState（唯一状态源）+ AppScope（注入）
├── pages/                    页面：ledger / identities / settings
├── widgets/                  通用组件（列表行、高亮文本、弹层、对话框）
└── services/                 导出、导入、功能清单解析、触感
assets/features.txt           功能清单，App 内解析渲染
ci/android/AndroidManifest.xml  构建时覆盖的清单，禁网 + 应用名
.github/workflows/            云端构建 Android APK / 桌面端
```

分层约束：

- 页面不碰 SQL，DAO 不处理界面逻辑
- 加功能只动对应目录；新增字段类型只需扩展 `models/enums.dart` 与对应编辑器
- CSV 加列只改 `core/csv_columns.dart`，说明面板与解析逻辑自动同步

## 数据模型

五张业务表 + 一张偏好表。

| 表 | 说明 |
|---|---|
| `folders` | 文件夹，一层，带图标与颜色，可拖动排序 |
| `records` | 记录本体，自定义字段存 `extra_json`，登录方式存 `logins_json` |
| `identities` | 身份池：手机号 / 邮箱 / QQ / 微信 / 其他 |
| `field_defs` | 自定义字段定义，四种作用范围可选全局或指定文件夹 |
| `settings` | 界面偏好（排序、视图、上次登录类型），不参与导出 |

关键取舍：

- 登录方式存在记录内部的 JSON 数组里，不建通用关系图谱；「某身份被谁引用」通过启动时扫描 `logins_json` 在内存建索引
- 登录方式引用身份池时，展示取池里的最新值（改一处全变）；删除身份时引用方自动降级为纯文本并保留最后的值
- 所有删除都是软删除（`deleted_at`），回收站里可恢复，手动清空才物理删除
- 未填的可选项一律存 `NULL`

## 构建

本地不需要任何 Flutter 环境，构建全部在 GitHub Actions 云端完成。**日常提交不会触发构建，只有推送版本 tag 才构建并发布到 Release。**

发一版：

```bash
git tag v0.1.0 && git push origin v0.1.0
```

触发后依次执行：

1. `flutter create --platforms=android` 生成 Android 工程脚手架（仓库不存平台目录）
2. 用 `ci/android/AndroidManifest.xml` 覆盖清单，移除 `INTERNET` 权限并设置应用名
3. `flutter build apk --release`，产物上传为 artifact，同时创建或更新同名 Release 并挂上 APK
4. 构建后校验合并清单里没有 `INTERNET` 权限，有则构建失败

不想打 tag、只想确认代码能编译时，在 Actions 页面手动 Run workflow（`workflow_dispatch`），此时只上传 artifact、不建 Release。

Flutter 版本固定为 `3.50.0`（`.github/workflows/build-android.yml`），依赖锁定在 `pubspec.yaml`。

## 数据格式

导出为单个 zip：`asset-ledger-YYYYMMDD-HHmm.zip`，内含 `records.csv`、`identities.csv`、
`folders.csv`、`field_defs.csv`、`meta.json`。UTF-8 带 BOM，Excel / WPS 双击不乱码。

导入支持 zip 与 csv 两种输入，流程：解析 → 预览（新增 / 更新 / 未变化 / 冲突、新字段）→
选冲突策略（跳过 / 覆盖 / 全部新建）→ 快照 → 单事务写入。

降低门槛的核心规则：**列名认不出来的一律当自定义字段**，按文本类型自动建字段定义。
完整说明见应用内「设置 → 导入 → CSV 格式怎么写」。

## 隐私

- Android 包不声明 `INTERNET` 权限，系统层面保证无法联网
- 不申请任何运行时权限
- 不采集任何统计、不写外部存储；导出的文件通过系统分享面板交给用户自己处理

## 版本

发版时同步更新三处：`pubspec.yaml` 的 `version`、`core/app_info.dart` 的 `version`、
`assets/features.txt` 顶部新增版本块。
