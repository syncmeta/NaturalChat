"""
sandbox.py - Code execution sandbox with platform-specific isolation.

Automatically selects the best available sandbox:
  1. Docker (all platforms, best isolation)
  2. Bubblewrap (Linux)
  3. sandbox-exec (macOS)
  4. WSL2 (Windows)
  5. Bare subprocess (fallback, no isolation)

Override with NATURALCHAT_SANDBOX env var: docker, bubblewrap, sandbox-exec, wsl, none
"""

import asyncio
import logging
import os
import platform
import shutil
import subprocess
import tempfile
from abc import ABC, abstractmethod

logger = logging.getLogger(__name__)

_OS = platform.system()  # "Linux", "Darwin", "Windows"


class SandboxRunner(ABC):
    """Abstract sandbox for running Python code."""

    name: str = "unknown"

    @abstractmethod
    async def run_code(self, code: str, timeout: float, cwd: str) -> tuple[str, str, int]:
        """Run Python code and return (stdout, stderr, exit_code)."""
        ...


class DockerSandbox(SandboxRunner):
    """Run code in a Docker container with full isolation."""

    name = "docker"

    def __init__(self, image: str = "naturalchat-sandbox:latest"):
        self.image = image
        self._image_ensured = False

    async def _ensure_image(self):
        """Build sandbox image if it doesn't exist."""
        if self._image_ensured:
            return

        proc = await asyncio.create_subprocess_exec(
            "docker", "image", "inspect", self.image,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await proc.wait()

        if proc.returncode != 0:
            # Try to build from Dockerfile.sandbox
            dockerfile = os.path.join(
                os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                "docker", "Dockerfile.sandbox"
            )
            if os.path.isfile(dockerfile):
                logger.info(f"Building sandbox image from {dockerfile}...")
                proc = await asyncio.create_subprocess_exec(
                    "docker", "build", "-t", self.image, "-f", dockerfile, ".",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
                await proc.wait()
                if proc.returncode != 0:
                    logger.warning("Failed to build sandbox image, using python:3.11-slim")
                    self.image = "python:3.11-slim"
            else:
                logger.info("No Dockerfile.sandbox found, using python:3.11-slim")
                self.image = "python:3.11-slim"

        self._image_ensured = True

    async def run_code(self, code: str, timeout: float, cwd: str) -> tuple[str, str, int]:
        await self._ensure_image()

        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False, dir=cwd) as f:
            f.write(code)
            script_name = os.path.basename(f.name)
            script_path = f.name

        try:
            proc = await asyncio.create_subprocess_exec(
                "docker", "run", "--rm",
                "--network=none",
                "--memory=128m",
                "--cpus=0.5",
                "--read-only",
                "--tmpfs", "/tmp:size=64m",
                "-v", f"{cwd}:/workspace:rw",
                "-w", "/workspace",
                self.image,
                "python3", f"/workspace/{script_name}",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            try:
                stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout + 5)
                return stdout.decode("utf-8", errors="replace"), stderr.decode("utf-8", errors="replace"), proc.returncode
            except asyncio.TimeoutError:
                proc.kill()
                await proc.communicate()
                return "", "Execution timed out", 1
        finally:
            try:
                os.unlink(script_path)
            except OSError:
                pass


class BubblewrapSandbox(SandboxRunner):
    """Run code in a bubblewrap sandbox (Linux only)."""

    name = "bubblewrap"

    async def run_code(self, code: str, timeout: float, cwd: str) -> tuple[str, str, int]:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
            f.write(code)
            temp_path = f.name

        try:
            # Find python3 path
            python_path = shutil.which("python3") or "python3"

            cmd = [
                "bwrap",
                "--ro-bind", "/usr", "/usr",
                "--ro-bind", "/lib", "/lib",
                "--ro-bind", "/bin", "/bin",
                "--symlink", "usr/lib64", "/lib64",
                "--proc", "/proc",
                "--dev", "/dev",
                "--tmpfs", "/tmp",
                "--bind", cwd, "/workspace",
                "--bind", temp_path, "/tmp/script.py",
                "--unshare-all",
                "--die-with-parent",
                "--chdir", "/workspace",
                python_path, "/tmp/script.py",
            ]

            # Add /lib64 if it exists as a real directory
            if os.path.isdir("/lib64") and not os.path.islink("/lib64"):
                cmd[cmd.index("--symlink"):cmd.index("--symlink") + 3] = ["--ro-bind", "/lib64", "/lib64"]

            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            try:
                stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
                return stdout.decode("utf-8", errors="replace"), stderr.decode("utf-8", errors="replace"), proc.returncode
            except asyncio.TimeoutError:
                proc.kill()
                await proc.communicate()
                return "", "Execution timed out", 1
        finally:
            try:
                os.unlink(temp_path)
            except OSError:
                pass


class SandboxExecRunner(SandboxRunner):
    """Run code using macOS sandbox-exec (deny network, restrict filesystem)."""

    name = "sandbox-exec"

    _PROFILE_TEMPLATE = """(version 1)
(deny default)
(allow process*)
(allow sysctl-read)
(allow mach-lookup)
(allow ipc-posix*)
(allow file-read*
    (subpath "/usr")
    (subpath "/Library")
    (subpath "/System")
    (subpath "/private/var")
    (subpath "/dev")
    (subpath "/Applications/Xcode.app")
    (subpath "/opt/homebrew")
    (subpath "/private/tmp")
    (literal "/")
)
(allow file-read* file-write*
    (subpath "{workspace}")
    (subpath "/private/tmp")
    (subpath "{tmpdir}")
)
(deny network*)
"""

    async def run_code(self, code: str, timeout: float, cwd: str) -> tuple[str, str, int]:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
            f.write(code)
            temp_path = f.name

        tmpdir = tempfile.gettempdir()
        profile = self._PROFILE_TEMPLATE.format(workspace=cwd, tmpdir=tmpdir)

        with tempfile.NamedTemporaryFile(mode="w", suffix=".sb", delete=False) as pf:
            pf.write(profile)
            profile_path = pf.name

        try:
            python_path = shutil.which("python3") or "python3"
            proc = await asyncio.create_subprocess_exec(
                "sandbox-exec", "-f", profile_path,
                python_path, temp_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=cwd,
            )
            try:
                stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
                return stdout.decode("utf-8", errors="replace"), stderr.decode("utf-8", errors="replace"), proc.returncode
            except asyncio.TimeoutError:
                proc.kill()
                await proc.communicate()
                return "", "Execution timed out", 1
        finally:
            for p in (temp_path, profile_path):
                try:
                    os.unlink(p)
                except OSError:
                    pass


class WindowsSandbox(SandboxRunner):
    """Run code on Windows: prefer WSL2, fallback to bare subprocess with warning."""

    name = "windows"

    def __init__(self):
        self._has_wsl = self._check_wsl()

    @staticmethod
    def _check_wsl() -> bool:
        try:
            result = subprocess.run(
                ["wsl", "--status"],
                capture_output=True, timeout=5,
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False

    async def run_code(self, code: str, timeout: float, cwd: str) -> tuple[str, str, int]:
        if self._has_wsl:
            return await self._run_wsl(code, timeout, cwd)
        return await self._run_bare(code, timeout, cwd)

    async def _run_wsl(self, code: str, timeout: float, cwd: str) -> tuple[str, str, int]:
        """Run code inside WSL2 for isolation."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False, dir=cwd) as f:
            f.write(code)
            temp_path = f.name

        try:
            # Convert Windows path to WSL path
            wsl_path = temp_path.replace("\\", "/")
            # Use wslpath if available, otherwise simple conversion
            wsl_cwd = cwd.replace("\\", "/")

            proc = await asyncio.create_subprocess_exec(
                "wsl", "python3", wsl_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=cwd,
            )
            try:
                stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
                return stdout.decode("utf-8", errors="replace"), stderr.decode("utf-8", errors="replace"), proc.returncode
            except asyncio.TimeoutError:
                proc.kill()
                await proc.communicate()
                return "", "Execution timed out", 1
        finally:
            try:
                os.unlink(temp_path)
            except OSError:
                pass

    async def _run_bare(self, code: str, timeout: float, cwd: str) -> tuple[str, str, int]:
        """Bare subprocess fallback on Windows."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False, dir=cwd) as f:
            f.write(code)
            temp_path = f.name

        try:
            python_path = shutil.which("python") or shutil.which("python3") or "python"
            CREATE_NO_WINDOW = 0x08000000
            proc = await asyncio.create_subprocess_exec(
                python_path, temp_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=cwd,
                creationflags=CREATE_NO_WINDOW if _OS == "Windows" else 0,
            )
            try:
                stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
                return stdout.decode("utf-8", errors="replace"), stderr.decode("utf-8", errors="replace"), proc.returncode
            except asyncio.TimeoutError:
                proc.kill()
                await proc.communicate()
                return "", "Execution timed out", 1
        finally:
            try:
                os.unlink(temp_path)
            except OSError:
                pass


class BareSubprocessSandbox(SandboxRunner):
    """No sandbox — runs code directly as current user. Used as last resort."""

    name = "none"

    async def run_code(self, code: str, timeout: float, cwd: str) -> tuple[str, str, int]:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
            f.write(code)
            temp_path = f.name

        try:
            python_path = shutil.which("python3") or shutil.which("python") or "python3"
            proc = await asyncio.create_subprocess_exec(
                python_path, temp_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=cwd,
            )
            try:
                stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
                return stdout.decode("utf-8", errors="replace"), stderr.decode("utf-8", errors="replace"), proc.returncode
            except asyncio.TimeoutError:
                proc.kill()
                await proc.communicate()
                return "", "Execution timed out", 1
        finally:
            try:
                os.unlink(temp_path)
            except OSError:
                pass


def _check_docker() -> bool:
    """Check if Docker is available and running."""
    try:
        result = subprocess.run(
            ["docker", "info"],
            capture_output=True, timeout=10,
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _check_bwrap() -> bool:
    """Check if bubblewrap is available."""
    return _OS == "Linux" and shutil.which("bwrap") is not None


def get_sandbox() -> SandboxRunner:
    """Auto-detect and return the best available sandbox."""
    override = os.environ.get("NATURALCHAT_SANDBOX", "").lower().strip()

    if override:
        mapping = {
            "docker": DockerSandbox,
            "bubblewrap": BubblewrapSandbox,
            "bwrap": BubblewrapSandbox,
            "sandbox-exec": SandboxExecRunner,
            "sandbox_exec": SandboxExecRunner,
            "wsl": WindowsSandbox,
            "windows": WindowsSandbox,
            "none": BareSubprocessSandbox,
        }
        cls = mapping.get(override)
        if cls:
            logger.info(f"Sandbox: using {override} (from NATURALCHAT_SANDBOX env)")
            return cls()
        logger.warning(f"Unknown sandbox type '{override}', auto-detecting...")

    # Auto-detect
    if _check_docker():
        logger.info("Sandbox: Docker detected, using Docker sandbox (best isolation)")
        return DockerSandbox()

    if _OS == "Linux" and _check_bwrap():
        logger.info("Sandbox: bubblewrap detected, using bwrap sandbox")
        return BubblewrapSandbox()

    if _OS == "Darwin":
        logger.info("Sandbox: macOS detected, using sandbox-exec")
        return SandboxExecRunner()

    if _OS == "Windows":
        sandbox = WindowsSandbox()
        if sandbox._has_wsl:
            logger.info("Sandbox: WSL2 detected on Windows, using WSL sandbox")
        else:
            logger.warning(
                "Sandbox: Windows without WSL2/Docker — code runs with limited isolation. "
                "Install Docker Desktop or WSL2 for better security."
            )
        return sandbox

    logger.warning(
        "Sandbox: No sandbox available! Code will run unsandboxed as current user. "
        "Install Docker for proper isolation."
    )
    return BareSubprocessSandbox()
