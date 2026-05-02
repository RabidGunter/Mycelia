# Git Setup for Mycelia

One-time setup guide for putting the project under git, plus the asymmetric workflow that keeps the work laptop safe (pull-only) while the personal machine is the source of truth.

After this is set up, manual zip transfers between machines stop. `git pull` replaces them.

---

## Why bother

- **Replaces manual zip transfers.** Sync between machines becomes one command.
- **Version history.** Roll back, compare, recover from mistakes.
- **Branch-based experiments.** Try Phase 1 ProfileService migration on a branch; if it goes wrong, throw the branch away.
- **Asymmetric safety.** Personal machine pushes; work laptop pulls. No outbound credentials from work, but you still get the work laptop's planning sessions onto the canonical project via patch-and-apply.

---

## First-time setup (personal machine only — NEVER on work laptop)

The `git init` and the GitHub remote setup happen exactly once, on the personal machine where the canonical code lives.

### Step 1: Verify git is installed

Open a terminal on the personal machine. Run:

```bash
git --version
```

If it says `git version 2.x.x`, you're set. If "command not found," install from [git-scm.com](https://git-scm.com).

### Step 2: Configure git identity

```bash
git config --global user.name "RabidGunter"
git config --global user.email "your-personal-email@example.com"
```

**Use a personal email here, not a work email.** Commits attributed to a work email on a personal repo create awkward audit trails.

### Step 3: Initialize the repo

Navigate to the project root (the folder containing `default.project.json`) and:

```bash
cd /path/to/mycelia
git init
```

### Step 4: Sanity-check what gets committed

The `.gitignore` already excludes `.rbxl` files, editor configs, and OS junk. Verify nothing sensitive sneaks in:

```bash
git status
```

You should see your source files, the `docs/` folder, `HANDOFF.md`, `README.md`, etc. **You should NOT see** any `.rbxl` files, `.vscode/` folders, secrets, or `node_modules/`-equivalents. If you do, add them to `.gitignore` first.

### Step 5: First commit

```bash
git add .
git commit -m "Initial commit — Pre-Alpha foundation + Phase 1 planning"
```

### Step 6: Create the GitHub repo

**Option A — via the GitHub web UI:**
1. Go to [github.com/new](https://github.com/new).
2. Repository name: `mycelia` (or any name you like).
3. **Visibility: Private.** Don't make it public yet.
4. **Do NOT** check "Initialize with README" or "Add .gitignore" — your local repo already has both.
5. Click Create.
6. Follow the "push an existing repository" instructions GitHub shows you.

**Option B — via gh CLI** (if you have [GitHub CLI](https://cli.github.com) installed):
```bash
gh repo create mycelia --private --source=. --push
```
This does steps 6–7 in one shot.

### Step 7: Connect remote and push

(Skip this if you used gh CLI in Option B — it already pushed.)

```bash
git remote add origin git@github.com:RabidGunter/mycelia.git
git branch -M main
git push -u origin main
```

If SSH isn't set up, the URL is `https://github.com/RabidGunter/mycelia.git` instead. Git will prompt for username + password (or personal access token) on push.

After this, `https://github.com/RabidGunter/mycelia` exists privately and contains your project. Personal machine is now the canonical source.

---

## Work-laptop workflow (pull-only)

The work laptop receives updates from the personal machine via `git pull`. It never pushes.

### First-time clone on work laptop

```bash
cd ~/Downloads
git clone https://github.com/RabidGunter/mycelia.git
```

(Or whatever path you prefer. HTTPS is fine for read-only clone — you'll be prompted to log in once for the private repo, then GitHub credentials cache.)

This replaces the manually-zipped `Mycelia/` folder you've been using. Going forward, just `cd mycelia && git pull` to receive the latest.

### Receiving updates

Anytime the personal machine has pushed new work:

```bash
cd ~/Downloads/mycelia
git pull
```

That's it. The new code, docs, ADRs, specs all appear locally.

### Never push from work laptop

The hard rule. Don't `git push` from this machine. Even to a private repo.

**Why:** outbound traffic to github.com under your personal credentials is exactly the kind of thing work network monitoring flags. Reading from a private repo (clone, pull) doesn't require credentials to leave the network in the same way.

If you make changes on the work laptop you want on the personal machine, two options:

**Option 1 — generate a patch (cleaner for substantial work):**

```bash
# On work laptop, after making changes:
git add .
git commit -m "Planning sprint: doc reorg + ADRs"
git format-patch origin/main..HEAD --output-directory=~/Downloads/patches/
```

This creates `.patch` files in `~/Downloads/patches/`. Copy them to a USB drive, transfer to personal machine. There:

```bash
# On personal machine:
cd ~/Documents/Mycelia/mycelia
git am ~/path/to/patches/0001-*.patch
git push
```

`git am` applies patches as commits, preserving the commit message and authorship. The personal machine then pushes them.

**Option 2 — copy raw files (simpler for small edits):**

Just copy the changed files via USB, like we've been doing. On the personal machine, review the changes, commit and push there.

Use Option 1 when you've done substantial planning work and want commit history preserved. Use Option 2 for one-off file edits.

---

## Daily flow (once set up)

### On personal machine (where code happens)

After every Definition-of-Done complete (per [CONTRIBUTING.md](CONTRIBUTING.md)):

```bash
git add .
git commit -m "Implement substrate compatibility for plant flow (per ADR 002)"
git push
```

Commit messages should describe WHY, not just WHAT. "Add yieldBySubstrate field" is bad; "Implement substrate compatibility per ADR 002, gating Epic cultivation behind magical loam" is good.

### Branches for substantial features

Don't commit straight to `main` for risky changes:

```bash
git checkout -b feature/profile-service-migration
# ... work, commit, work, commit ...
git checkout main
git merge feature/profile-service-migration --no-ff
git push
```

`--no-ff` keeps the branch as a visible block in history rather than melting it into linear commits.

For trivial work (typo fix, doc tweak, single config change), commit straight to `main` is fine.

### When the work laptop has staged work

```bash
# Personal machine:
git pull
# (then if work-laptop sent patches, apply them)
git am ~/transferred/patches/*.patch
git push
```

Work laptop sees updates next `git pull`. Sync complete.

---

## What NOT to commit (recap of `.gitignore`)

Already excluded:
- `*.rbxl`, `*.rbxlx`, `*.rbxm`, `*.rbxmx` — Roblox binary place files. Always edit in Studio, never in git.
- `.vscode/`, `.idea/` — editor local state.
- `.DS_Store`, `Thumbs.db`, `desktop.ini` — OS junk.
- `~/.aftman/`, `~/.foreman/` — toolchain cache.

What you should add as you go:
- Vendored dependencies (e.g., `src/ServerScriptService/Vendor/`) — actually DO commit these. Vendoring's whole point is reproducibility.
- Wally packages folder (if you ever add Wally) — usually ignored, since `wally install` regenerates them.
- API keys / DataStore secrets — never commit. Use Roblox attributes or runtime config.

If you're unsure whether something should be committed, ask: "If a stranger cloned this repo right now, would they get a working project AND have it not contain my secrets?"

---

## Recovering from mistakes

Some commands worth knowing:

| Need | Command |
|---|---|
| See what's changed but uncommitted | `git status` and `git diff` |
| Discard uncommitted changes to one file | `git checkout -- path/to/file` |
| Undo last commit (keep changes) | `git reset --soft HEAD~1` |
| Undo last commit (throw away changes) | `git reset --hard HEAD~1` (DESTRUCTIVE) |
| See commit history | `git log --oneline --graph --all` |
| Compare two commits | `git diff <hash1> <hash2>` |
| Find when a line changed | `git blame path/to/file` |

`git reset --hard` and `git push --force` are the destructive ones. Avoid them on `main`. Branch operations are cheap and recoverable; `main` operations should be deliberate.

---

## After setup — first thing to do

Update [HANDOFF.md](../HANDOFF.md) "Working across machines" section to reflect that the project is now in git and machines sync via pull. The manual-zip era is over.

---

*Originally written 2026-05-01 on work laptop. The git setup itself happens on personal machine, when you next have an opportunity to do it. Follow steps 1–7 above in one sitting (~15 minutes).*
