import { parse as parseYaml } from "yaml";

/**
 * SKILL.md frontmatter 中的参数定义
 */
export interface SkillParameter {
  type: string;
  description: string;
  required?: boolean;
  default?: unknown;
}

/**
 * SKILL.md 解析结果
 */
export interface ParsedSkill {
  name: string;
  description: string;
  parameters?: Record<string, SkillParameter>;
  instructions: string;
}

/**
 * 解析 SKILL.md 文件内容
 *
 * 格式：YAML frontmatter（---分隔）+ Markdown body
 */
export function parseSkillMd(content: string): ParsedSkill {
  const trimmed = content.trim();

  // 解析 frontmatter
  if (!trimmed.startsWith("---")) {
    throw new Error("SKILL.md 缺少 YAML frontmatter（应以 --- 开头）");
  }

  const endIndex = trimmed.indexOf("---", 3);
  if (endIndex === -1) {
    throw new Error("SKILL.md frontmatter 未闭合（缺少第二个 ---）");
  }

  const frontmatterStr = trimmed.slice(3, endIndex).trim();
  const body = trimmed.slice(endIndex + 3).trim();

  let frontmatter: Record<string, unknown>;
  try {
    frontmatter = parseYaml(frontmatterStr) as Record<string, unknown>;
  } catch (e) {
    throw new Error(`SKILL.md frontmatter YAML 解析失败: ${e instanceof Error ? e.message : String(e)}`);
  }

  if (!frontmatter || typeof frontmatter !== "object") {
    throw new Error("SKILL.md frontmatter 必须是一个对象");
  }

  const name = frontmatter.name;
  const description = frontmatter.description;

  if (typeof name !== "string" || !name) {
    throw new Error("SKILL.md frontmatter 缺少 name 字段");
  }

  if (typeof description !== "string" || !description) {
    throw new Error("SKILL.md frontmatter 缺少 description 字段");
  }

  // 解析 parameters（可选）
  let parameters: Record<string, SkillParameter> | undefined;
  if (frontmatter.parameters && typeof frontmatter.parameters === "object") {
    parameters = frontmatter.parameters as Record<string, SkillParameter>;
  }

  return {
    name,
    description,
    parameters,
    instructions: body,
  };
}
