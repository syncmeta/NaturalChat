# Plan: 010-memory-system

## 技术方案

### FileMemory 实现

- 位置: `src/memory/file-memory.ts`
- 存储路径: `<botDir>/data/memory/<sanitized-contactId>.json`
- contactId 转文件名: 替换 `:` → `_`, 其他非法文件名字符用 encodeURIComponent
- JSON 格式存储完整 UserContext
- 使用写入锁（per-contactId Promise chain）确保串行写入

### 文件结构

```
src/memory/
  file-memory.ts     # FileMemory 实现
tests/memory/
  file-memory.test.ts
```

### Brain 集成

- SimpleBrain 构造函数增加可选 `memory?: Memory` 参数
- handleMessage 中：
  1. 消息处理前 `memory.getContext(contactId)`
  2. 如果有 summary，追加到 system prompt
  3. 处理完成后 `memory.updateContext(contactId, { lastInteraction: new Date() })`

### 依赖

- Node.js fs/promises (mkdir, readFile, writeFile)
- 现有 Memory 接口 (`src/core/interfaces/memory.ts`)
- 现有 UserContext 类型 (`src/core/types.ts`)
