import type { Skill, SkillMeta, Tool } from "../types.js";

/**
 * SkillLoader — 技能系统接口
 *
 * 遵循 Anthropic Agent Skills 规范。
 * 采用渐进加载：discover 只读 frontmatter 元数据，loadSkill 按需加载完整内容。
 */
export interface SkillLoader {
  /** 扫描目录，读取 SKILL.md frontmatter（name, description） */
  discover(dirs: string[]): Promise<SkillMeta[]>;

  /** 按需加载完整技能内容（body + scripts） */
  loadSkill(name: string): Promise<Skill>;

  /** 将已发现的技能转为 LLM tool format */
  getToolDefinitions(): Tool[];

  /** 执行技能脚本 */
  execute(name: string, params: Record<string, unknown>): Promise<string>;
}
