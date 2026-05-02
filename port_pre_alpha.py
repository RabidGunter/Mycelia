"""
Port the working Pre-Alpha code from `mycelia/src/` to the new top-level
`src/` structure, applying path adjustments for the new project.json layout
(server is now wrapped under a Server Script).

Old layout                                  → New layout
------------------------------------------- → -----------------------------
mycelia/src/ReplicatedStorage/Shared/X.lua  → src/shared/X.luau
mycelia/src/ServerScriptService/X.lua       → src/server/X.luau
mycelia/src/ServerScriptService/Tests/X.lua → src/server/Tests/X.luau
mycelia/src/ServerScriptService/Main.server.lua → src/server/init.server.luau
mycelia/src/StarterPlayer/.../X.client.lua  → src/client/X.client.luau

Path rewrites on import:
- require(ServerScriptService.X)            → require(ServerScriptService.Server.X)
- require(ServerScriptService.Tests.X)      → require(ServerScriptService.Server.Tests.X)
"""

import re
import shutil
from pathlib import Path

OLD_ROOT = Path(r"C:\Users\fonte\Documents\Mycelia\mycelia\src")
NEW_ROOT = Path(r"C:\Users\fonte\Documents\Mycelia\src")

# Already done: shared modules. Skip them here.

# Path rewrites: applied to file CONTENT after copy.
# Pattern: capture `ServerScriptService.X` (where X is a module name) and
# rewrite to `ServerScriptService.Server.X`. The Tests subfolder also needs
# wrapping in .Server.
REWRITES = [
    # require(ServerScriptService.Tests.X) → require(ServerScriptService.Server.Tests.X)
    (re.compile(r"\bServerScriptService\.Tests\b"), "ServerScriptService.Server.Tests"),
    # require(ServerScriptService.X) → require(ServerScriptService.Server.X)
    # Match ServerScriptService.X where X is a single identifier (not already .Server)
    (re.compile(r"\bServerScriptService\.(?!Server\b)(\w+)"), r"ServerScriptService.Server.\1"),
]


def transform(content: str) -> str:
    for pattern, replacement in REWRITES:
        content = pattern.sub(replacement, content)
    return content


def port_file(src: Path, dst: Path):
    dst.parent.mkdir(parents=True, exist_ok=True)
    text = src.read_text(encoding="utf-8")
    text = transform(text)
    dst.write_text(text, encoding="utf-8")
    print(f"  {src.relative_to(OLD_ROOT)} -> {dst.relative_to(NEW_ROOT)}")


def main():
    server_dir = NEW_ROOT / "server"
    client_dir = NEW_ROOT / "client"

    # Wipe stub files so we start clean (preserves the directories themselves)
    stubs_to_remove = [
        server_dir / "init.server.luau",
        client_dir / "init.client.luau",
    ]
    for stub in stubs_to_remove:
        if stub.exists():
            stub.unlink()
            print(f"  removed stub: {stub.relative_to(NEW_ROOT)}")

    # ---- Server modules (excluding Main.server.lua and Tests subfolder) ----
    server_src = OLD_ROOT / "ServerScriptService"
    print("\n== Server modules ==")
    for f in sorted(server_src.glob("*.lua")):
        if f.name == "Main.server.lua":
            # Goes to init.server.luau
            dst = server_dir / "init.server.luau"
        else:
            new_name = f.name.replace(".lua", ".luau")
            dst = server_dir / new_name
        port_file(f, dst)

    # ---- Tests subfolder ----
    tests_src = server_src / "Tests"
    print("\n== Tests ==")
    for f in sorted(tests_src.glob("*.lua")):
        new_name = f.name.replace(".lua", ".luau")
        dst = server_dir / "Tests" / new_name
        port_file(f, dst)

    # ---- Client modules ----
    client_src = OLD_ROOT / "StarterPlayer" / "StarterPlayerScripts"
    print("\n== Client modules ==")
    for f in sorted(client_src.glob("*.lua")):
        new_name = f.name.replace(".lua", ".luau")
        dst = client_dir / new_name
        port_file(f, dst)

    print("\nDone.")


if __name__ == "__main__":
    main()
