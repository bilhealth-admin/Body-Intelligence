"""Prepare direct Gradle checks without building or changing pinned properties."""

import os
import shutil
from pathlib import Path


def prepare(android: Path, flutter: Path, android_sdk: Path) -> None:
    properties = android / "gradle/wrapper/gradle-wrapper.properties"
    pinned = properties.read_bytes()
    wrapper = flutter / "bin/cache/artifacts/gradle_wrapper"
    # Same source and copy-if-missing behavior as Flutter's GradleUtils.
    for relative in ("gradlew", "gradlew.bat", "gradle/wrapper/gradle-wrapper.jar"):
        source = wrapper / relative
        if not source.is_file():
            raise FileNotFoundError(source)
        target = android / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            shutil.copyfile(source, target)
    local = android / "local.properties"
    lines = local.read_text().splitlines() if local.exists() else []
    lines = [line for line in lines if not line.startswith(("flutter.sdk=", "sdk.dir="))]
    lines += [f"flutter.sdk={flutter.as_posix()}", f"sdk.dir={android_sdk.as_posix()}"]
    local.write_text("\n".join(lines) + "\n", encoding="utf-8")
    assert properties.read_bytes() == pinned, "Pinned Gradle properties changed"


if __name__ == "__main__":
    prepare(
        Path("android"),
        Path(os.environ["FLUTTER_ROOT"]),
        Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"]),
    )
