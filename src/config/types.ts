import type { z } from "zod";
import type {
  GlobalConfigSchema,
  ModelConfigSchema,
  BotConfigSchema,
  BotSecretsSchema,
  ChannelEntrySchema,
} from "./schema.js";

/** 全局配置 */
export type GlobalConfig = z.infer<typeof GlobalConfigSchema>;

/** 模型配置（6 种任务） */
export type ModelConfig = z.infer<typeof ModelConfigSchema>;

/** Bot 配置 */
export type BotConfig = z.infer<typeof BotConfigSchema>;

/** Bot 密钥 */
export type BotSecrets = z.infer<typeof BotSecretsSchema>;

/** Channel 条目 */
export type ChannelEntry = z.infer<typeof ChannelEntrySchema>;

/** 合并后的完整 Bot 配置（运行时使用） */
export interface ResolvedBotConfig {
  name: string;
  description: string;
  models: ModelConfig;
  channels: ChannelEntry[];
  secrets: BotSecrets;
  botDir: string;
}
