"""
config_validation.py - Lightweight schema validation for bot config and skill definitions.
"""

from __future__ import annotations

import copy
from typing import Any, Dict, List, Tuple


class ConfigValidationError(ValueError):
    pass


def deep_merge(base: dict, override: dict) -> dict:
    result = copy.deepcopy(base)
    for key, val in (override or {}).items():
        if isinstance(result.get(key), dict) and isinstance(val, dict):
            result[key] = deep_merge(result[key], val)
        else:
            result[key] = copy.deepcopy(val)
    return result


def load_yaml_file(path: str) -> dict:
    import yaml

    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    if not isinstance(data, dict):
        raise ConfigValidationError(f"{path} must contain a YAML object at the top level.")
    return data


def validate_bot_config(config: Dict[str, Any], context: str = "bot config") -> Dict[str, Any]:
    errors: List[str] = []
    validated = copy.deepcopy(config or {})

    transports = validated.get("transports", {})
    if not isinstance(transports, dict) or not transports:
        errors.append("transports must be a non-empty mapping")
    else:
        _validate_transports(transports, errors)

    llm = validated.get("llm", {})
    if not isinstance(llm, dict):
        errors.append("llm must be a mapping")
    else:
        _require_str(llm, "base_url", "llm.base_url", errors)
        _require_str(llm, "model", "llm.model", errors)
        _require_int(llm, "max_history_tokens", "llm.max_history_tokens", errors, minimum=1)

    _optional_number(validated, "msg_wait_initial", errors, minimum=0)
    _optional_number(validated, "msg_wait_after_typing_stop", errors, minimum=0)
    _optional_number(validated, "typing_hard_timeout", errors, minimum=0)
    _optional_number(validated, "reflection_delay", errors, minimum=0)

    token_budget = validated.get("token_budget", {})
    if token_budget:
        if not isinstance(token_budget, dict):
            errors.append("token_budget must be a mapping")
        else:
            _require_int(token_budget, "default_score", "token_budget.default_score", errors, minimum=0, maximum=100)

    models = validated.get("models", [])
    if models:
        if not isinstance(models, list):
            errors.append("models must be a list")
        else:
            for idx, item in enumerate(models):
                if not isinstance(item, dict):
                    errors.append(f"models[{idx}] must be an object")
                    continue
                _require_str(item, "name", f"models[{idx}].name", errors)
                _require_str(item, "role", f"models[{idx}].role", errors)
                _require_str(item, "model", f"models[{idx}].model", errors)

    if errors:
        raise ConfigValidationError(f"Invalid {context}:\n- " + "\n- ".join(errors))

    return validated


def validate_skill_definition(skill: Dict[str, Any]) -> Tuple[bool, List[str]]:
    errors: List[str] = []

    if not isinstance(skill.get("name"), str) or not skill["name"].strip():
        errors.append("name must be a non-empty string")
    if not isinstance(skill.get("description"), str) or not skill["description"].strip():
        errors.append("description must be a non-empty string")
    if not callable(skill.get("execute")):
        errors.append("execute must be callable")

    parameters = skill.get("parameters", {})
    if not isinstance(parameters, dict):
        errors.append("parameters must be an object schema")
    else:
        if parameters.get("type", "object") != "object":
            errors.append("parameters.type must be 'object'")
        if "properties" in parameters and not isinstance(parameters.get("properties"), dict):
            errors.append("parameters.properties must be a mapping")
        if "required" in parameters and not isinstance(parameters.get("required"), list):
            errors.append("parameters.required must be a list")

    return (not errors, errors)


def _validate_transports(transports: Dict[str, Any], errors: List[str]) -> None:
    enabled_count = 0
    for name, cfg in transports.items():
        if not isinstance(cfg, dict):
            errors.append(f"transports.{name} must be a mapping")
            continue
        if not cfg.get("enabled"):
            continue
        enabled_count += 1
        if name == "telegram":
            _require_str(cfg, "token", "transports.telegram.token", errors)
        elif name == "xmpp":
            _require_str(cfg, "jid", "transports.xmpp.jid", errors)
            _require_str(cfg, "password", "transports.xmpp.password", errors)
        elif name == "matrix":
            _require_str(cfg, "homeserver_url", "transports.matrix.homeserver_url", errors)
            _require_str(cfg, "user_id", "transports.matrix.user_id", errors)
            if not cfg.get("access_token") and not cfg.get("password"):
                errors.append("transports.matrix requires access_token or password")
        elif name == "feishu":
            _require_str(cfg, "app_id", "transports.feishu.app_id", errors)
            _require_str(cfg, "app_secret", "transports.feishu.app_secret", errors)
        else:
            errors.append(f"unsupported transport: {name}")
    if enabled_count == 0:
        errors.append("at least one enabled transport is required")


def _require_str(data: Dict[str, Any], key: str, path: str, errors: List[str]) -> None:
    value = data.get(key)
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{path} must be a non-empty string")


def _require_int(data: Dict[str, Any], key: str, path: str, errors: List[str], minimum: int | None = None, maximum: int | None = None) -> None:
    value = data.get(key)
    if not isinstance(value, int):
        errors.append(f"{path} must be an integer")
        return
    if minimum is not None and value < minimum:
        errors.append(f"{path} must be >= {minimum}")
    if maximum is not None and value > maximum:
        errors.append(f"{path} must be <= {maximum}")


def _optional_number(data: Dict[str, Any], key: str, errors: List[str], minimum: float | None = None) -> None:
    if key not in data:
        return
    value = data.get(key)
    if not isinstance(value, (int, float)):
        errors.append(f"{key} must be a number")
        return
    if minimum is not None and value < minimum:
        errors.append(f"{key} must be >= {minimum}")
