import os

WORKSPACE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), "workspace")
os.makedirs(WORKSPACE_DIR, exist_ok=True)

# Initialize sandbox (auto-detects best available)
from src.sandbox import get_sandbox
_sandbox = get_sandbox()


async def execute(code: str) -> str:
    """Execute Python code in a sandboxed subprocess with timeout."""
    stdout, stderr, exit_code = await _sandbox.run_code(
        code=code, timeout=10.0, cwd=WORKSPACE_DIR
    )

    result_parts = []
    if stdout:
        result_parts.append(f"Output:\n{stdout}")
    if stderr:
        result_parts.append(f"Error:\n{stderr}")
    if not result_parts:
        result_parts.append("Code execution completed, no output.")

    return "\n".join(result_parts)
