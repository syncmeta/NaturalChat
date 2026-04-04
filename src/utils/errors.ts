/**
 * 配置相关错误：YAML 解析失败、Zod 校验失败等
 */
export class ConfigError extends Error {
  constructor(
    message: string,
    public readonly filePath?: string,
    public readonly details?: string[],
  ) {
    super(message);
    this.name = "ConfigError";
  }
}

/**
 * Bot 加载错误：目录不存在、配置缺失等
 */
export class BotLoadError extends Error {
  constructor(
    message: string,
    public readonly botName: string,
    public readonly cause?: Error,
  ) {
    super(message);
    this.name = "BotLoadError";
  }
}
