#!/usr/bin/env python3

from pathlib import Path
import secrets
import sys

import yaml


def load_env_file(path: Path) -> dict:
    if not path.exists():
        return {}
    data = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.lstrip().startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key.strip()] = value.strip()
    return data


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: render_memobase_config.py <bot_dir> <output_dir>", file=sys.stderr)
        return 1

    bot_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)

    config_path = bot_dir / "config.yaml"
    secrets_path = bot_dir / "secrets.yaml"
    if not config_path.exists():
        print(f"missing config: {config_path}", file=sys.stderr)
        return 1

    bot_cfg = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    secrets_cfg = yaml.safe_load(secrets_path.read_text(encoding="utf-8")) or {} if secrets_path.exists() else {}
    llm_cfg = dict(bot_cfg.get("llm", {}) or {})
    llm_cfg.update(secrets_cfg.get("llm", {}) or {})
    mem_cfg = dict(bot_cfg.get("memobase", {}) or {})
    mem_cfg.update(secrets_cfg.get("memobase", {}) or {})

    llm_api_key = llm_cfg.get("api_key", "")
    llm_base_url = llm_cfg.get("base_url", "https://api.openai.com/v1")
    llm_model = llm_cfg.get("model", "openai/gpt-4o-mini")
    access_token = mem_cfg.get("api_key", "secret")
    existing_env = load_env_file(output_dir / ".env")

    config = {
        "language": "Chinese",
        "llm_api_key": llm_api_key,
        "llm_base_url": llm_base_url,
        "best_llm_model": llm_model,
        "extractor_llm_model": llm_model,
        "enable_event_embedding": False,
        "prompt": {
            "chat_blob": {
                "disable": False,
            },
            "event": {
                "disable": True,
            },
            "profile": {
                "disable": False,
            },
        },
    }

    env = {
        "DATABASE_USER": "memobase",
        "DATABASE_PASSWORD": existing_env.get("DATABASE_PASSWORD", secrets.token_urlsafe(24)),
        "DATABASE_NAME": "memobase",
        "DATABASE_LOCATION": "/opt/naturalchat4/memobase/postgres",
        "DATABASE_EXPORT_PORT": "5433",
        "REDIS_PASSWORD": existing_env.get("REDIS_PASSWORD", secrets.token_urlsafe(24)),
        "REDIS_LOCATION": "/opt/naturalchat4/memobase/redis",
        "REDIS_EXPORT_PORT": "6380",
        "ACCESS_TOKEN": access_token,
        "PROJECT_ID": existing_env.get("PROJECT_ID", "naturalchat4"),
        "API_HOSTS": existing_env.get("API_HOSTS", "*"),
        "USE_CORS": existing_env.get("USE_CORS", "1"),
        "API_EXPORT_PORT": "8019",
    }

    (output_dir / "config.yaml").write_text(
        yaml.safe_dump(config, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    (output_dir / ".env").write_text(
        "\n".join(f"{k}={v}" for k, v in env.items()) + "\n",
        encoding="utf-8",
    )

    print(f"wrote {output_dir / 'config.yaml'}")
    print(f"wrote {output_dir / '.env'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
