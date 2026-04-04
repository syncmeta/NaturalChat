import { z } from "zod";

/** 模型配置 Schema — 6 种任务的模型 */
export const ModelConfigSchema = z.object({
  chat: z.string(),
  critic: z.string(),
  surf_planner: z.string(),
  surf_evaluator: z.string(),
  reflection: z.string(),
  summary: z.string(),
});

/** 部分模型配置 Schema — Bot 级覆盖用 */
export const PartialModelConfigSchema = ModelConfigSchema.partial();

/** Channel 条目 Schema */
export const ChannelEntrySchema = z.object({
  type: z.string(),
  enabled: z.boolean().default(true),
});

/** 全局配置 Schema */
export const GlobalConfigSchema = z.object({
  api_base_url: z.string().url(),
  api_key: z.string().min(1),
  models: ModelConfigSchema,
});

/** Bot 配置 Schema */
export const BotConfigSchema = z.object({
  name: z.string().min(1),
  description: z.string().default(""),
  models: PartialModelConfigSchema.optional(),
  channels: z.array(ChannelEntrySchema).default([]),
});

/** Bot 密钥 Schema — 按 Channel 类型分组的键值对 */
export const BotSecretsSchema = z.record(z.string(), z.record(z.string(), z.string()));
