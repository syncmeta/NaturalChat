---
name: "manage_skills"
description: "Manage the skill library for yourself (and all bots). You can use this skill to create brand new directory-based skills (Progressive Disclosure), or query/delete skills. All skills take effect globally immediately after hot-reload."
parameters:
  type: "object"
  properties:
    action:
        type: "string"
        enum: ["list", "create_or_update", "delete"]
        description: "The action to perform: list = list skills, create_or_update = create/update a skill, delete = delete a skill"
    skill_name:
        type: "string"
        description: "The English name of the skill (use all lowercase with underscores, e.g., my_awesome_skill)"
    description:
        type: "string"
        description: "(Only provide when creating) This description will be mounted in your System Prompt to tell you when you should immediately call this skill. Therefore, use clear trigger scenario descriptions."
    parameters_json:
        type: "string"
        description: "(Only provide when creating) Provide skill parameters in JSON string format. Must include type, properties, and required fields. For example: '{\"type\": \"object\", \"properties\": {\"arg1\": {\"type\": \"string\"}}, \"required\": [\"arg1\"]}'."
    markdown_body:
        type: "string"
        description: "(Only provide when creating) The core prompt for the skill. After the skill executes, the Markdown rules here will teach you how to analyze the return results and organize the final reply."
    python_code:
        type: "string"
        description: "(Only provide when creating) The actual Python execution code for the skill. Must contain `async def execute(**kwargs) -> str:`. If omitted, a lightweight soft skill that operates purely on prompts will be created."
  required: ["action"]
---

## Meta Skill Management Guide (Progressive Disclosure)

When you `create_or_update` a skill:
1. **Prioritize properly**: `description` is only used to help you decide whether to call this function -- keep it as short as possible; `markdown_body` is used to tell you how to respond to the user based on the produced data after the function runs.
2. **Text-only skills**: If you just want to establish a fixed behavior or template for yourself without executing additional Python code, you can omit the `python_code` parameter.
3. **Version control**: The system automatically records the skill files you generate via Git in the background for future traceability.
