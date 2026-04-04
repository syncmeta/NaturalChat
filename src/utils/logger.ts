import pino from "pino";

const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
  redact: {
    paths: ["*.api_key", "*.token", "*.password", "api_key", "token", "password"],
    censor: "[REDACTED]",
  },
  transport:
    process.env.NODE_ENV !== "production"
      ? { target: "pino/file", options: { destination: 1 } }
      : undefined,
});

export default logger;
