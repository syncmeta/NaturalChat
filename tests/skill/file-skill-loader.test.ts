import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdir, writeFile, rm, chmod } from "node:fs/promises";
import { join } from "node:path";
import { FileSkillLoader } from "../../src/skill/file-skill-loader.js";

const TEST_DIR = join(import.meta.dirname, "../../tmp-test-skills");
const SKILLS_DIR = join(TEST_DIR, "skills");

async function createSkill(
  name: string,
  opts?: { params?: string; body?: string; script?: string },
): Promise<void> {
  const dir = join(SKILLS_DIR, name);
  await mkdir(dir, { recursive: true });

  const params = opts?.params ?? "";
  const body = opts?.body ?? `# ${name}\n\n使用此技能。`;

  await writeFile(
    join(dir, "SKILL.md"),
    `---\nname: ${name}\ndescription: ${name}技能\n${params}---\n\n${body}`,
  );

  if (opts?.script) {
    const scriptsDir = join(dir, "scripts");
    await mkdir(scriptsDir, { recursive: true });
    await writeFile(join(scriptsDir, "run.sh"), opts.script);
    await chmod(join(scriptsDir, "run.sh"), 0o755);
  }
}

describe("FileSkillLoader", () => {
  let loader: FileSkillLoader;

  beforeEach(async () => {
    await mkdir(SKILLS_DIR, { recursive: true });
    loader = new FileSkillLoader({ timeoutMs: 5000 });
  });

  afterEach(async () => {
    await rm(TEST_DIR, { recursive: true, force: true });
  });

  it("discovers skills from directories", async () => {
    await createSkill("weather");
    await createSkill("translate");

    const metas = await loader.discover([SKILLS_DIR]);

    expect(metas).toHaveLength(2);
    const names = metas.map((m) => m.name);
    expect(names).toContain("weather");
    expect(names).toContain("translate");
  });

  it("handles non-existent skills directory", async () => {
    const metas = await loader.discover(["/tmp/no-such-skills"]);
    expect(metas).toEqual([]);
  });

  it("skips directories without valid SKILL.md", async () => {
    await createSkill("valid");
    // Create directory without SKILL.md
    await mkdir(join(SKILLS_DIR, "broken"), { recursive: true });
    await writeFile(join(SKILLS_DIR, "broken", "SKILL.md"), "not valid yaml");

    const metas = await loader.discover([SKILLS_DIR]);
    expect(metas).toHaveLength(1);
    expect(metas[0].name).toBe("valid");
  });

  it("loads full skill with scripts", async () => {
    await createSkill("echo", {
      script: '#!/bin/bash\necho "hello"',
    });

    await loader.discover([SKILLS_DIR]);
    const skill = await loader.loadSkill("echo");

    expect(skill.name).toBe("echo");
    expect(skill.instructions).toContain("echo");
    expect(skill.scripts).toContain("run.sh");
  });

  it("throws when loading unknown skill", async () => {
    await loader.discover([SKILLS_DIR]);
    await expect(loader.loadSkill("nonexistent")).rejects.toThrow("技能不存在");
  });

  it("generates tool definitions with parameters", async () => {
    await createSkill("search", {
      params: `parameters:
  query:
    type: string
    description: 搜索关键词
    required: true
  limit:
    type: number
    description: 结果数
    default: 5
`,
    });

    await loader.discover([SKILLS_DIR]);
    const tools = loader.getToolDefinitions();

    expect(tools).toHaveLength(1);
    expect(tools[0].type).toBe("function");
    expect(tools[0].function.name).toBe("search");
    expect(tools[0].function.parameters).toEqual({
      type: "object",
      properties: {
        query: { type: "string", description: "搜索关键词" },
        limit: { type: "number", description: "结果数", default: 5 },
      },
      required: ["query"],
    });
  });

  it("generates tool definitions without parameters", async () => {
    await createSkill("simple");

    await loader.discover([SKILLS_DIR]);
    const tools = loader.getToolDefinitions();

    expect(tools).toHaveLength(1);
    expect(tools[0].function.parameters).toEqual({
      type: "object",
      properties: {},
    });
  });

  it("executes skill script", async () => {
    await createSkill("hello", {
      script: '#!/bin/bash\necho "Hello World"',
    });

    await loader.discover([SKILLS_DIR]);
    const result = await loader.execute("hello", {});

    expect(result).toBe("Hello World");
  });

  it("passes parameters via SKILL_PARAMS env", async () => {
    await createSkill("params-test", {
      script: '#!/bin/bash\necho "$SKILL_PARAMS"',
    });

    await loader.discover([SKILLS_DIR]);
    const result = await loader.execute("params-test", { city: "上海" });
    const parsed = JSON.parse(result);
    expect(parsed.city).toBe("上海");
  });

  it("returns message for skill without scripts", async () => {
    await createSkill("no-script");

    await loader.discover([SKILLS_DIR]);
    const result = await loader.execute("no-script", {});
    expect(result).toContain("没有可执行的脚本");
  });

  it("discovers from multiple directories", async () => {
    const dir2 = join(TEST_DIR, "common_skills");
    await mkdir(dir2, { recursive: true });
    await createSkill("local");

    // Create skill in second directory
    const commonSkillDir = join(dir2, "common");
    await mkdir(commonSkillDir, { recursive: true });
    await writeFile(
      join(commonSkillDir, "SKILL.md"),
      "---\nname: common\ndescription: 通用技能\n---\n\n通用。",
    );

    const metas = await loader.discover([SKILLS_DIR, dir2]);
    expect(metas).toHaveLength(2);
  });
});
