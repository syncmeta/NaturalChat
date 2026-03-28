import os
import ast
import subprocess
import json
import yaml
import shutil

# Root directory (for executing Git commands)
_ROOT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# common_skills/ directory
_SKILLS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _git_commit(rel_path: str, message: str) -> str:
    """Commit the specific path to git. Auto-init if needed."""
    try:
        res = subprocess.run(["git", "status"], cwd=_ROOT_DIR, capture_output=True)
        if res.returncode != 0:
            subprocess.run(["git", "init"], cwd=_ROOT_DIR, check=True)
            subprocess.run(["git", "config", "user.name", "AI Bot"], cwd=_ROOT_DIR)
            subprocess.run(["git", "config", "user.email", "bot@localhost"], cwd=_ROOT_DIR)

        subprocess.run(["git", "add", rel_path], cwd=_ROOT_DIR, check=True)
        status = subprocess.run(["git", "status", "--porcelain", rel_path], cwd=_ROOT_DIR, capture_output=True, text=True)
        if status.stdout.strip():
            res = subprocess.run(["git", "commit", "-m", message], cwd=_ROOT_DIR, capture_output=True, text=True)
            if res.returncode == 0:
                return f"(Version recorded: {message})"
        return "(No changes)"
    except Exception as e:
        return f"(Git recording failed: {e})"


async def execute(action: str, skill_name: str = "", description: str = "", parameters_json: str = "", markdown_body: str = "", python_code: str = "") -> str:
    if action == "list":
        skills = []
        for item in sorted(os.listdir(_SKILLS_DIR)):
            if item.startswith("_"):
                continue
            item_path = os.path.join(_SKILLS_DIR, item)

            # Directory based skill
            if os.path.isdir(item_path):
                md_path = os.path.join(item_path, "SKILL.md")
                if os.path.exists(md_path):
                    try:
                        with open(md_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                        import re
                        match = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
                        if match:
                            fm = yaml.safe_load(match.group(1))
                            skills.append(f"• {fm.get('name', item)} [Directory]: {fm.get('description', '')[:80]}")
                    except:
                        skills.append(f"• {item} [Directory]")
            # Legacy script
            elif item.endswith(".py"):
                skills.append(f"• {item} [Legacy Python]")

        if not skills:
            return "No skills currently available."
        return "Current skill list:\n" + "\n".join(skills)

    elif action == "create_or_update":
        if not skill_name or not description:
            return "Error: skill_name and description are required to create a skill."

        # Parse parameters json
        try:
            params = json.loads(parameters_json) if parameters_json.strip() else {"type": "object", "properties": {}}
        except Exception as e:
            return f"Invalid parameters JSON format: {str(e)}"

        # Validate python code if provided
        if python_code.strip():
            try:
                tree = ast.parse(python_code)
                has_execute = any(isinstance(n, ast.AsyncFunctionDef) and n.name == "execute" for n in ast.walk(tree))
                if not has_execute:
                    return "Python code is missing the async def execute function entry point."
            except SyntaxError as e:
                return f"Python syntax error: {e}"

        skill_dir = os.path.join(_SKILLS_DIR, skill_name)
        os.makedirs(skill_dir, exist_ok=True)

        # Write SKILL.md
        frontmatter = {
            "name": skill_name,
            "description": description,
            "parameters": params
        }
        yaml_str = yaml.dump(frontmatter, allow_unicode=True, default_flow_style=False)
        md_content = f"---\n{yaml_str}---\n\n{markdown_body}"

        with open(os.path.join(skill_dir, "SKILL.md"), "w", encoding="utf-8") as f:
            f.write(md_content)

        # Write Python script if provided
        if python_code.strip():
            script_dir = os.path.join(skill_dir, "scripts")
            os.makedirs(script_dir, exist_ok=True)
            with open(os.path.join(script_dir, f"{skill_name}.py"), "w", encoding="utf-8") as f:
                f.write(python_code)

        rel_path = os.path.relpath(skill_dir, _ROOT_DIR)
        git_res = _git_commit(rel_path, f"bot: create/update skill '{skill_name}'")

        return f"Skill '{skill_name}' has been deployed. {git_res}\nSystem hot-reload will take effect in a few seconds."

    elif action == "delete":
        if not skill_name:
            return "Error: skill_name is required."

        if skill_name in ("manage_skills", "skill_manager"):
            return "Error: Cannot delete the skill manager itself."

        skill_dir = os.path.join(_SKILLS_DIR, skill_name)
        legacy_file = os.path.join(_SKILLS_DIR, f"{skill_name}.py")

        deleted = False
        target_path = None

        if os.path.exists(skill_dir) and os.path.isdir(skill_dir):
            target_path = skill_dir
            shutil.rmtree(skill_dir)
            deleted = True
        elif os.path.exists(legacy_file):
            target_path = legacy_file
            os.remove(legacy_file)
            deleted = True

        if deleted:
            rel_path = os.path.relpath(target_path, _ROOT_DIR)
            subprocess.run(["git", "add", "-u", rel_path], cwd=_ROOT_DIR) # Stage the deletion
            git_res = _git_commit(rel_path, f"bot: delete skill '{skill_name}'")
            return f"Skill '{skill_name}' has been deleted. {git_res} Hot-reload will take effect shortly."
        else:
            return f"Error: Cannot find a skill named '{skill_name}'."

    else:
        return f"Error: Unknown action '{action}'. Currently only list/create_or_update/delete are supported."
