# 工具箱 (toolbox)

多功能工具箱 App，按《开发.txt》的架构实现。当前已落地**记账**工具，其余工具（图片转文字、语音转文字、视频剪辑、格式转换）以占位卡片注册在首页，预留后续开发空间。

## 架构概览

- **monorepo + 模块化**：每个工具是独立 feature 包，共享 `core` 层。
- **工具契约**：`core/tool/` 定义 `ToolDescriptor` / `ToolModule` / `ToolRegistry`。新增工具只需实现 `ToolModule` 并注册到 `tool_registry.dart`，首页宫格与路由自动生效。
- **数据库**：Drift 单 database 类汇总所有 feature 的表；表定义放在各自 feature 下。
- **纯本地**：所有数据存在 SQLite，文件不出手机。

## 目录结构

```
toolbox/
├── pubspec.yaml
└── lib/
    ├── main.dart
    ├── app.dart
    ├── core/
    │   ├── tool/            # 工具契约 + 注册表
    │   ├── database/        # Drift 汇总入口（含生成的 app_database.g.dart）
    │   ├── router/          # go_router 路由
    │   ├── theme/           # 主题
    │   ├── ui/              # 图标映射、占位页
    │   └── util/            # 金额格式化
    └── features/
        ├── home/            # 首页宫格
        └── ledger/          # 记账（第一个工具）
            ├── ledger_module.dart
            ├── data/        # 表结构 + DAO（含生成的 ledger_dao.g.dart）
            └── presentation/ # providers + 页面 + 组件
```

## 已验证

在 Flutter 3.47.2 / Dart 3.13.2 环境下：

- `flutter pub get`：成功解析 104 个依赖
- `dart run build_runner build --delete-conflicting-outputs`：成功生成 Drift 代码
- `dart analyze lib`：**No issues found**（0 错误 0 警告）

## 跑起来

在已安装 Flutter（Dart SDK ^3.5.0，建议 Flutter 3.27+）的机器上：

```bash
# 1. 生成平台脚手架（android/ios），若当前目录尚未有 android/ ios/ 目录
flutter create --org com.yourname --platforms=android,ios .

# 2. 拉依赖
flutter pub get

# 3. 生成 Drift 代码（app_database.g.dart / ledger_dao.g.dart，无需手写）
dart run build_runner build --delete-conflicting-outputs

# 4. 运行
flutter run
```

> `build_runner` 生成的两个 `.g.dart` 文件不需要提交，已加入 `.gitignore`（`*.g.dart`）。

## 相对原 spec 的修正

开发过程中按真实编译结果修正了以下问题：

1. **依赖版本**（Flutter 3.47 SDK 要求，否则 `pub get` 失败）：
   - `path: 1.9.0` → `^1.9.1`
   - `intl: 0.19.0` → `^0.20.3`
   - `collection: 1.18.0` → `^1.19.1`

2. **种子数据 Companion 传参**（Drift 的 `Companion.insert()` 中：无默认值列传原始值、有默认值/可空列包 `Value(...)`）：
   - `CategoriesCompanion.insert(kind: ...)`：`const Value(EntryKind.expense)` → `EntryKind.expense`（`income` 同理）
   - `AccountsCompanion.insert(iconKey: ...)`：`'cash'` → `const Value('cash')`（`bank`/`wallet` 同理）

3. **`ledger_dao.dart` 缺 `part` 指令**：`_$LedgerDaoMixin` 由 build_runner 生成在 `ledger_dao.g.dart`，原 spec 漏了 `part 'ledger_dao.g.dart';`，已补上。

4. **`entry_editor_page.dart` 缺 import**：`Category` / `Account` / `LedgerEntriesCompanion` 由 Drift 生成在 `app_database.g.dart`，原 spec 未 import，已补 `import '../../../core/database/app_database.dart';`。

5. **`watchSummary` 的枚举比较**：`selectOnly` 读取 `textEnum` 列返回的是原始字符串（枚举名），原 spec 用 `kind == EntryKind.income` 恒为 false，已改为 `kind == EntryKind.income.name`（`expense` 同理）。

## 后续加工具的步骤（引自 spec）

以图片转文字为例，只需三步：

1. 建 `features/ocr/`，写 `OcrModule extends ToolModule`，返回 descriptor 和 routes。
2. 把 `tool_registry.dart` 里的 `_PlannedTool(id: 'ocr', ...)` 换成 `OcrModule()`。
3. 如需建表，把表类加到 `app_database.dart` 的 `tables` 数组，`schemaVersion` 加 1 并补 `onUpgrade`。
