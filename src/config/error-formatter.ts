import type { ZodError } from "zod";

/**
 * 将 ZodError 转为中文友好的错误信息
 *
 * 输出格式：
 * ```
 * 配置校验失败: config.yaml
 *   - models.chat: 期望 string, 实际 number
 *   - name: 必填字段缺失
 * ```
 */
export function formatZodError(error: ZodError, filePath?: string): string {
  const header = filePath ? `配置校验失败: ${filePath}` : "配置校验失败";

  const lines = error.issues.map((issue) => {
    const path = issue.path.length > 0 ? issue.path.join(".") : "(根)";
    const message = translateZodMessage(issue);
    return `  - ${path}: ${message}`;
  });

  return [header, ...lines].join("\n");
}

function translateZodMessage(issue: {
  code: string;
  message: string;
  expected?: unknown;
  received?: unknown;
}): string {
  switch (issue.code) {
    case "invalid_type":
      if (issue.received === "undefined") {
        return "必填字段缺失";
      }
      return `期望 ${String(issue.expected)}, 实际 ${String(issue.received)}`;
    case "invalid_string":
      return `无效的字符串格式 (${issue.message})`;
    case "too_small":
      return "不能为空";
    case "invalid_union":
      return "值不匹配任何允许的类型";
    default:
      return issue.message;
  }
}
