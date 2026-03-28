"""
skill_loader.py - Load common and bot-specific skills for LLM function calling.

Supports legacy single-file (.py) skills and new progressive-disclosure 
directory structure (SKILL.md + scripts/).
"""

import os
import importlib.util
import logging
import yaml
import re
from typing import Optional, List
from src.config_validation import validate_skill_definition

logger = logging.getLogger(__name__)

def _parse_skill_md(filepath: str):
    """Parse YAML frontmatter and markdown body from SKILL.md"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    match = re.match(r'^---\s*\n(.*?)\n---\s*\n(.*)', content, re.DOTALL)
    if not match:
        logger.warning(f"No YAML frontmatter found in {filepath}")
        return None, content
    
    yaml_text = match.group(1)
    markdown_body = match.group(2).strip()
    try:
        frontmatter = yaml.safe_load(yaml_text)
        return frontmatter, markdown_body
    except yaml.YAMLError as e:
        logger.error(f"Failed to parse YAML in {filepath}: {e}")
        return None, content

def _load_skill_from_dir_structure(skill_dir: str) -> Optional[dict]:
    """Load a skill from the new progressive disclosure directory structure."""
    skill_md_path = os.path.join(skill_dir, "SKILL.md")
    if not os.path.exists(skill_md_path):
        return None
        
    frontmatter, markdown_body = _parse_skill_md(skill_md_path)
    if not frontmatter:
        return None
        
    skill_name = frontmatter.get("name")
    description = frontmatter.get("description")
    parameters = frontmatter.get("parameters", {"type": "object", "properties": {}})
    if "type" not in parameters:
        parameters["type"] = "object"
    
    if not skill_name or not description:
        logger.warning(f"Skill {skill_dir} missing name or description in frontmatter.")
        return None
        
    # Check for python script in scripts/
    scripts_dir = os.path.join(skill_dir, "scripts")
    original_execute = None
    
    if os.path.isdir(scripts_dir):
        # Look for a .py file that matches the skill name or main.py/execute.py
        for candidate in [f"{skill_name}.py", "main.py", "execute.py"]:
            script_path = os.path.join(scripts_dir, candidate)
            if os.path.exists(script_path):
                try:
                    spec = importlib.util.spec_from_file_location(f"skill_{skill_name}", script_path)
                    if spec and spec.loader:
                        module = importlib.util.module_from_spec(spec)
                        spec.loader.exec_module(module)
                        if hasattr(module, "execute"):
                            original_execute = module.execute
                            break
                except Exception as e:
                    logger.error(f"Failed to load script {script_path}: {e}")
                    
    # Progressive disclosure wrapper
    if original_execute is not None:
        async def wrapped_execute(**kwargs):
            try:
                result = await original_execute(**kwargs)
                if markdown_body:
                    return f"[Skill Execution Result]\n{result}\n\n[Skill Guidelines]\nRead and strictly follow these guidelines in your subsequent replies:\n{markdown_body}"
                return str(result)
            except Exception as e:
                error_msg = f"【Skill Execution Error】\n{str(e)}"
                if markdown_body:
                    error_msg += f"\n\n[Skill Guidelines]\nRead and strictly follow these guidelines in your subsequent replies:\n{markdown_body}"
                return error_msg
        final_execute = wrapped_execute
    else:
        async def default_execute(**kwargs):
            return f"[Skill Guidelines]\nRead and strictly follow these guidelines in your final thinking and replies:\n{markdown_body}"
        final_execute = default_execute
        
    skill = {
        "name": skill_name,
        "description": description,
        "parameters": parameters,
        "execute": final_execute,
        "source": skill_dir,
    }
    ok, errors = validate_skill_definition(skill)
    if not ok:
        logger.warning(f"Skill {skill_dir} failed validation: {'; '.join(errors)}")
        return None
    return skill

def _load_skill_from_file(filepath: str) -> Optional[dict]:
    """Load a single skill from a legacy Python file."""
    try:
        spec = importlib.util.spec_from_file_location("skill", filepath)
        if spec is None or spec.loader is None:
            return None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        required_attrs = ["SKILL_NAME", "SKILL_DESCRIPTION", "SKILL_PARAMETERS", "execute"]
        for attr in required_attrs:
            if not hasattr(module, attr):
                logger.warning(f"Skill {filepath} missing required attribute: {attr}")
                return None

        skill = {
            "name": module.SKILL_NAME,
            "description": module.SKILL_DESCRIPTION,
            "parameters": module.SKILL_PARAMETERS,
            "execute": module.execute,
            "source": filepath,
        }
        ok, errors = validate_skill_definition(skill)
        if not ok:
            logger.warning(f"Skill {filepath} failed validation: {'; '.join(errors)}")
            return None
        return skill
    except Exception as e:
        logger.error(f"Failed to load skill from {filepath}: {e}")
        return None

def _load_skills_from_dir(directory: str) -> List[dict]:
    """Load all skills from a directory (supports both .py and SKILL.md subdirs)."""
    skills = []
    if not os.path.isdir(directory):
        return skills
    for item in sorted(os.listdir(directory)):
        if item.startswith("_"):
            continue
            
        item_path = os.path.join(directory, item)
        
        # New Directory Structure
        if os.path.isdir(item_path):
            if os.path.exists(os.path.join(item_path, "SKILL.md")):
                skill = _load_skill_from_dir_structure(item_path)
                if skill:
                    skills.append(skill)
                    logger.info(f"  Loaded progressive skill: {skill['name']} ({item_path})")
                    
        # Legacy Python File
        elif os.path.isfile(item_path) and item.endswith(".py"):
            skill = _load_skill_from_file(item_path)
            if skill:
                skills.append(skill)
                logger.info(f"  Loaded legacy skill: {skill['name']} ({item_path})")
                
    return skills

def load_skills(common_skills_dir: str, bot_skills_dir: Optional[str] = None) -> List[dict]:
    """
    Load skills from common_skills/ and optional bot-specific skills/ directory.
    Returns a list of skill dicts with OpenAI tool format and execute functions.
    """
    skills = []

    # Load common skills
    logger.info(f"Loading common skills from: {common_skills_dir}")
    skills.extend(_load_skills_from_dir(common_skills_dir))

    # Load bot-specific skills
    if bot_skills_dir:
        logger.info(f"Loading bot-specific skills from: {bot_skills_dir}")
        skills.extend(_load_skills_from_dir(bot_skills_dir))

    return skills

def skills_to_openai_tools(skills: List[dict]) -> List[dict]:
    """Convert skill list to OpenAI function calling tools format."""
    tools = []
    for skill in skills:
        tools.append({
            "type": "function",
            "function": {
                "name": skill["name"],
                "description": skill["description"],
                "parameters": skill["parameters"],
            },
        })
    return tools

def get_skill_executor(skills: List[dict]) -> dict:
    """Return a mapping of skill_name -> execute function."""
    return {skill["name"]: skill["execute"] for skill in skills}
