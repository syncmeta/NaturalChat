import { readdir, readFile, stat } from "node:fs/promises";
import { join } from "node:path";
import { spawn } from "node:child_process";
import type { SkillLoader } from "../core/interfaces/skill-loader.js";
import type { Skill, SkillMeta, Tool } from "../core/types.js";
import { parseSkillMd, type ParsedSkill } from "./skill-parser.js";
import logger from "../utils/logger.js";

const log = logger.child({ module: "SkillLoader" });

const DEFAULT_TIMEOUT_MS = 30_000;

/**
 * FileSkillLoader — 基于文件系统的 SkillLoader 实现
 *
 * 扫描技能目录，解析 SKILL.md，执行 scripts/ 下的脚本。
 */
export class FileSkillLoader implements SkillLoader {
  private readonly discovered = new Map<string, { meta: SkillMeta; parsed: ParsedSkill; dir: string }>();
  private readonly timeoutMs: number;

  constructor(config?: { timeoutMs?: number }) {
    this.timeoutMs = config?.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  }

  async discover(dirs: string[]): Promise<SkillMeta[]> {
    this.discovered.clear();

    for (const dir of dirs) {
      try {
        const entries = await readdir(dir);
        for (const entry of entries) {
          if (entry.startsWith(".")) continue;

          const skillDir = join(dir, entry);
          const s = await stat(skillDir).catch(() => null);
          if (!s?.isDirectory()) continue;

          const skillMdPath = join(skillDir, "SKILL.md");
          try {
            const content = await readFile(skillMdPath, "utf-8");
            const parsed = parseSkillMd(content);

            const meta: SkillMeta = {
              name: parsed.name,
              description: parsed.description,
              dirPath: skillDir,
            };

            this.discovered.set(parsed.name, { meta, parsed, dir: skillDir });
            log.debug({ name: parsed.name, dir: skillDir }, "发现技能");
          } catch (e) {
            log.warn({ err: e, path: skillMdPath }, "技能加载失败，跳过");
          }
        }
      } catch {
        log.debug({ dir }, "技能目录不存在，跳过");
      }
    }

    log.info({ count: this.discovered.size }, "技能发现完成");
    return Array.from(this.discovered.values()).map((d) => d.meta);
  }

  async loadSkill(name: string): Promise<Skill> {
    const entry = this.discovered.get(name);
    if (!entry) {
      throw new Error(`技能不存在: ${name}`);
    }

    // 扫描 scripts/ 目录
    const scriptsDir = join(entry.dir, "scripts");
    let scripts: string[] = [];
    try {
      const files = await readdir(scriptsDir);
      scripts = files.filter((f) => !f.startsWith("."));
    } catch {
      // scripts/ 目录不存在也没关系
    }

    return {
      name: entry.parsed.name,
      description: entry.parsed.description,
      dirPath: entry.dir,
      instructions: entry.parsed.instructions,
      scripts,
    };
  }

  getToolDefinitions(): Tool[] {
    const tools: Tool[] = [];

    for (const [, entry] of this.discovered) {
      const { parsed } = entry;

      // 构建 JSON Schema parameters
      const properties: Record<string, unknown> = {};
      const required: string[] = [];

      if (parsed.parameters) {
        for (const [paramName, paramDef] of Object.entries(parsed.parameters)) {
          properties[paramName] = {
            type: paramDef.type,
            description: paramDef.description,
          };
          if (paramDef.default !== undefined) {
            (properties[paramName] as Record<string, unknown>).default = paramDef.default;
          }
          if (paramDef.required) {
            required.push(paramName);
          }
        }
      }

      tools.push({
        type: "function",
        function: {
          name: parsed.name,
          description: parsed.description,
          parameters: {
            type: "object",
            properties,
            ...(required.length > 0 ? { required } : {}),
          },
        },
      });
    }

    return tools;
  }

  async execute(name: string, params: Record<string, unknown>): Promise<string> {
    const skill = await this.loadSkill(name);

    if (skill.scripts.length === 0) {
      return `技能 ${name} 没有可执行的脚本`;
    }

    // 执行第一个脚本
    const scriptPath = join(skill.dirPath, "scripts", skill.scripts[0]);

    return new Promise<string>((resolve, reject) => {
      const proc = spawn("bash", [scriptPath], {
        env: {
          ...process.env,
          SKILL_PARAMS: JSON.stringify(params),
        },
        timeout: this.timeoutMs,
      });

      let stdout = "";
      let stderr = "";

      proc.stdout.on("data", (data) => {
        stdout += data.toString();
      });

      proc.stderr.on("data", (data) => {
        stderr += data.toString();
      });

      proc.on("close", (code) => {
        if (code === 0) {
          resolve(stdout.trim());
        } else {
          log.warn({ name, code, stderr }, "技能脚本执行失败");
          reject(new Error(`技能脚本执行失败 (exit ${code}): ${stderr.trim()}`));
        }
      });

      proc.on("error", (err) => {
        reject(new Error(`技能脚本启动失败: ${err.message}`));
      });
    });
  }
}
