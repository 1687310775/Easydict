# EasyDict 收藏夹 + Anki 导出功能需求文档（PRD）

## 项目目标

基于现有 EasyDict 项目进行二次开发，增加以下核心能力：

- 收藏单词
- 生词本管理
- Anki 导出
- 卡片模板系统
- AI 辅助制卡

最终将 EasyDict 从单纯查词工具升级为：

> 查词 → 收藏 → 生词本 → 制卡 → Anki 学习

---

# 第一阶段：项目分析

## 要求

在开始修改代码之前，先完整分析项目结构。

不要立即编写功能代码。

## 分析内容

### 1. 项目架构

分析：

- 技术栈
- 前端架构
- 后端架构
- 数据流

### 2. 查词流程

分析：

- 查询入口
- 数据获取方式
- 词条渲染流程

### 3. 单词详情页

分析：

- 页面结构
- 数据来源
- 可扩展位置

### 4. 本地存储

分析：

- 数据库存储方式
- 本地缓存方式
- 配置文件位置

### 5. 功能扩展方案

输出：

- 收藏功能实现方案
- Anki 导出实现方案
- UI 修改方案

## 输出文件

创建：

`docs/project-analysis.md`

内容包含：

- 项目架构图
- 目录结构
- 数据流分析
- 单词数据结构
- 收藏实现方案
- 导出实现方案

---

# 第二阶段：收藏功能

## 功能目标

允许用户收藏单词。

收藏数据永久保存。

软件关闭后重新打开仍然存在。

## UI需求

在单词详情页增加收藏按钮。

### 未收藏状态

`☆ Favorite`

### 已收藏状态

`★ Favorited`

点击后立即切换。

## 收藏数据结构

```typescript
interface FavoriteWord {
  id: string
  word: string
  phonetic?: string
  definition?: string
  translation?: string
  example?: string
  timestamp: number
}
```

## 数据存储

优先方案：

使用项目现有数据库。

如果项目无数据库：

`data/favorites.json`

自动生成并持久化保存。

## 收藏 API

```typescript
addFavorite(word)

removeFavorite(word)

toggleFavorite(word)

isFavorite(word)

getFavorites()

searchFavorites(keyword)

exportFavorites()
```

---

# 第三阶段：生词本页面

新增页面：

`Favorites`

## 页面展示

每条记录显示：

- 单词
- 音标
- 释义
- 收藏时间

## 页面功能

支持：

- 搜索
- 排序
- 删除
- 批量选择

## 排序方式

- 最新收藏
- 最早收藏
- 字母排序

---

# 第四阶段：Anki 导出

## 功能目标

将收藏内容直接导入 Anki。

## 导出格式

### CSV

```csv
Front,Back
abandon,"放弃"
```

### TSV

```text
Front    Back
abandon  放弃
```

### APKG（优先实现）

要求：

- 标准 Anki Package
- 兼容最新版 Anki
- 可直接导入

## 导出内容

### Front

`Word`

### Back

```text
Phonetic

Translation

Definition

Example
```

## 导出目录

`exports/`

---

# 第五阶段：卡片模板系统

新增页面：

`Card Templates`

## 预置模板

### 模板1：单词 → 中文

Front: Word

Back: Translation

### 模板2：单词 → 英文释义

Front: Word

Back: Definition

### 模板3：完整学习卡

Front: Word

Back:

- Phonetic
- Translation
- Example

### 模板4：反向记忆

Front: Translation

Back: Word

## 自定义模板

```json
{
  "name": "IELTS",
  "front": "{{word}}",
  "back": "{{phonetic}}<br>{{translation}}<br>{{example}}"
}
```

## 模板存储

`data/templates.json`

---

# 第六阶段：AI 辅助制卡

新增功能：

`Generate Card Content`

## 自动补充内容

- 中文释义
- 英文释义
- 例句
- 词根词缀
- 近义词
- 反义词
- 记忆技巧

## 示例结构

```typescript
interface CardContent {
  word: string
  translation: string
  definition: string
  example: string
  etymology: string
  synonyms: string[]
  antonyms: string[]
  memoryTip: string
}
```

---

# 技术要求

- 保持现有代码风格
- 保持现有架构设计
- 避免引入重量级依赖
- 增加 TypeScript 类型定义
- 增加错误处理
- 增加单元测试
- 增加 README 文档

---

# 测试要求

为以下模块增加测试：

- 收藏功能
- 搜索功能
- 排序功能
- 导出功能
- 模板功能
- AI 制卡功能

---

# 验收标准

- 收藏功能正常
- 软件重启后收藏仍存在
- 收藏夹支持搜索
- 收藏夹支持排序
- 收藏夹支持批量选择
- CSV 导出成功
- TSV 导出成功
- APKG 导出成功
- Anki 导入成功
- 自定义模板可正常使用
- AI生成内容可正常保存
- 无 TypeScript 报错
- 所有测试通过

---

# 开发流程要求

1. 分析项目
2. 收藏功能
3. 收藏夹页面
4. Anki导出
5. 模板系统
6. AI制卡
7. 单元测试
8. README更新

---

# 每阶段输出要求

每完成一个阶段：

- 修改文件列表
- 新增文件列表
- 实现原理说明
- 运行测试命令
- 潜在风险说明

不要一次性重构整个项目。

采用小步提交方式，方便 Review 和回滚。
