import { describe, it, expect } from "vitest";
import { parseSkillMd } from "../../src/skill/skill-parser.js";

describe("parseSkillMd", () => {
  it("parses valid SKILL.md with parameters", () => {
    const content = `---
name: weather
description: 查询天气信息
parameters:
  city:
    type: string
    description: 城市名称
    required: true
---

# 天气查询

当用户询问天气时，使用此技能。`;

    const result = parseSkillMd(content);

    expect(result.name).toBe("weather");
    expect(result.description).toBe("查询天气信息");
    expect(result.parameters).toBeDefined();
    expect(result.parameters!.city.type).toBe("string");
    expect(result.parameters!.city.required).toBe(true);
    expect(result.instructions).toContain("天气查询");
  });

  it("parses SKILL.md without parameters", () => {
    const content = `---
name: greeting
description: 打招呼
---

简单打个招呼就行。`;

    const result = parseSkillMd(content);

    expect(result.name).toBe("greeting");
    expect(result.description).toBe("打招呼");
    expect(result.parameters).toBeUndefined();
    expect(result.instructions).toBe("简单打个招呼就行。");
  });

  it("handles empty body", () => {
    const content = `---
name: noop
description: 什么都不做
---`;

    const result = parseSkillMd(content);

    expect(result.name).toBe("noop");
    expect(result.instructions).toBe("");
  });

  it("throws on missing frontmatter", () => {
    expect(() => parseSkillMd("# Just a heading")).toThrow("缺少 YAML frontmatter");
  });

  it("throws on unclosed frontmatter", () => {
    expect(() => parseSkillMd("---\nname: x\n")).toThrow("未闭合");
  });

  it("throws on missing name", () => {
    const content = `---
description: 没有名字
---

Body`;

    expect(() => parseSkillMd(content)).toThrow("缺少 name");
  });

  it("throws on missing description", () => {
    const content = `---
name: test
---

Body`;

    expect(() => parseSkillMd(content)).toThrow("缺少 description");
  });

  it("handles multiple parameters", () => {
    const content = `---
name: search
description: 搜索
parameters:
  query:
    type: string
    description: 搜索词
    required: true
  limit:
    type: number
    description: 结果数量
    default: 10
---

搜索指令。`;

    const result = parseSkillMd(content);

    expect(Object.keys(result.parameters!)).toHaveLength(2);
    expect(result.parameters!.query.required).toBe(true);
    expect(result.parameters!.limit.default).toBe(10);
  });
});
