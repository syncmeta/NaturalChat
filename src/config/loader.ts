import { parse as parseYaml } from "yaml";
import { GlobalConfigSchema, BotConfigSchema, BotSecretsSchema } from "./schema.js";
import { formatZodError } from "./error-formatter.js";
import { ConfigError } from "../utils/errors.js";
import type { GlobalConfig, BotConfig, BotSecrets, ModelConfig, ResolvedBotConfig } from "./types.js";

/**
 * 读取并解析 YAML 文件
 */
export async function readYaml(filePath: string): Promise<unknown> {
  const file = Bun.file(filePath);
  const exists = await file.exists();
  if (!exists) {
    throw new ConfigError(`文件不存在: ${filePath}`, filePath);
  }
  const text = await file.text();
  try {
    return parseYaml(text);
  } catch (e) {
    throw new ConfigError(
      `YAML 解析失败: ${filePath}`,
      filePath,
      [e instanceof Error ? e.message : String(e)],
    );
  }
}

/**
 * 加载并校验全局配置
 */
export async function parseGlobalConfig(filePath: string): Promise<GlobalConfig> {
  const raw = await readYaml(filePath);
  const result = GlobalConfigSchema.safeParse(raw);
  if (!result.success) {
    throw new ConfigError(
      formatZodError(result.error, filePath),
      filePath,
      result.error.issues.map((i) => i.message),
    );
  }
  return result.data;
}

/**
 * 加载并校验 Bot 配置
 */
export async function parseBotConfig(filePath: string): Promise<BotConfig> {
  const raw = await readYaml(filePath);
  const result = BotConfigSchema.safeParse(raw);
  if (!result.success) {
    throw new ConfigError(
      formatZodError(result.error, filePath),
      filePath,
      result.error.issues.map((i) => i.message),
    );
  }
  return result.data;
}

/**
 * 加载并校验 Bot 密钥（文件不存在返回空对象）
 */
export async function parseBotSecrets(filePath: string): Promise<BotSecrets> {
  const file = Bun.file(filePath);
  const exists = await file.exists();
  if (!exists) {
    return {};
  }
  const raw = await readYaml(filePath);
  if (raw === null || raw === undefined) {
    return {};
  }
  const result = BotSecretsSchema.safeParse(raw);
  if (!result.success) {
    throw new ConfigError(
      formatZodError(result.error, filePath),
      filePath,
      result.error.issues.map((i) => i.message),
    );
  }
  return result.data;
}

/**
 * 合并模型配置：Bot 的覆盖全局默认
 */
export function mergeModelConfig(
  globalModels: ModelConfig,
  botModels?: Partial<ModelConfig>,
): ModelConfig {
  if (!botModels) return { ...globalModels };
  return { ...globalModels, ...botModels };
}

/**
 * 构建完整的 ResolvedBotConfig
 */
export function resolveBotConfig(
  botConfig: BotConfig,
  botSecrets: BotSecrets,
  globalConfig: GlobalConfig,
  botDir: string,
): ResolvedBotConfig {
  return {
    name: botConfig.name,
    description: botConfig.description ?? "",
    models: mergeModelConfig(globalConfig.models, botConfig.models),
    channels: botConfig.channels ?? [],
    secrets: botSecrets,
    botDir,
  };
}
