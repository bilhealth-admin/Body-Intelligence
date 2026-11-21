"""Install the exact public Maven Central repository init only on a GitHub-hosted CI runner."""
from __future__ import annotations
import hashlib
import os
from pathlib import Path
import tempfile

ASSET_SHA256 = "2aefee6a65cd561b9c3446ade54e1ad08470acd4285eb14cb67d2e8289c30d56"
ASSET_RELATIVE = ".github/gradle/bil_ci_kotlin_central_mirror.init.gradle"
INIT_NAME = "bil_ci_kotlin_central_mirror.init.gradle"


def _ordinary(path: Path) -> None:
    for ancestor in (path, *path.parents):
        if ancestor.is_symlink():
            raise ValueError("CI Gradle paths must not contain symlinks")
        if ancestor.exists() and not ancestor.is_dir():
            raise ValueError("CI Gradle directory path is not ordinary")


def install(project_root: Path, environ=None, home=None) -> dict:
    env = os.environ if environ is None else environ
    if env.get("GITHUB_ACTIONS") != "true":
        return {"status": "not-github-actions", "modified": False}
    if env.get("RUNNER_ENVIRONMENT") != "github-hosted":
        raise ValueError("CI mirror installer requires an ephemeral GitHub-hosted runner")
    root = project_root.absolute()
    if Path(env.get("GITHUB_WORKSPACE", "__missing__")).absolute() != root:
        raise ValueError("CI mirror installer project is not GITHUB_WORKSPACE")
    runner_temp = Path(env.get("RUNNER_TEMP", "__missing__")).absolute()
    if not runner_temp.is_dir():
        raise ValueError("Expected existing RUNNER_TEMP")
    runner_home = Path.home() if home is None else Path(home)
    gradle_home = Path(env.get("GRADLE_USER_HOME", str(runner_home / ".gradle"))).absolute()
    # Reuse the ordinary per-runner Gradle cache; never erase or relocate it.
    if gradle_home != (runner_home / ".gradle").absolute() and not gradle_home.is_relative_to(runner_temp):
        raise ValueError("Custom GRADLE_USER_HOME must be owned under RUNNER_TEMP")
    if gradle_home == root or gradle_home.is_relative_to(root):
        raise ValueError("Refusing to install inside source")
    _ordinary(runner_temp)
    _ordinary(gradle_home / "init.d")
    asset = root / ASSET_RELATIVE
    if asset.is_symlink() or not asset.is_file():
        raise ValueError("Missing ordinary source-owned CI init asset")
    payload = asset.read_bytes()
    if hashlib.sha256(payload).hexdigest() != ASSET_SHA256:
        raise ValueError("CI init asset hash mismatch")
    destination = gradle_home / "init.d" / INIT_NAME
    if destination.is_symlink():
        raise ValueError("Refusing CI init symlink")
    if destination.exists():
        if not destination.is_file() or destination.read_bytes() != payload:
            raise ValueError("Refusing unknown existing CI init content")
        return {"status": "identical", "modified": False, "sha256": ASSET_SHA256}
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".bil-ci-init-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        # Hard-link publication is atomic and cannot overwrite a racing file.
        os.link(temporary, destination)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    if destination.read_bytes() != payload:
        raise ValueError("CI init publication readback mismatch")
    return {"status": "installed", "modified": True, "sha256": ASSET_SHA256}
