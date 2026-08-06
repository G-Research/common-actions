#!/usr/bin/env python3
"""Prototype: bucket zizmor fixes by (audit, disposition) and open one PR each."""
import json, os, subprocess, sys, tempfile
from collections import defaultdict
import yaml

REPO  = os.environ["GITHUB_REPOSITORY"]
TOKEN = os.environ["GH_TOKEN"]
BASE  = os.environ.get("GITHUB_REF_NAME") or \
        subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"]).decode().strip()

FIX_MODE = {"safe": "safe", "unsafe": "unsafe-only"}

def sh(cmd, **kw):
    return subprocess.run(cmd, **kw)

# --- load manifest -----------------------------------------------------------
manifest = json.load(open(os.environ.get("MANIFEST", "manifest.json")))
# candidates: has a fix AND not ignored/suppressed by repo policy
findings = [f for f in manifest if f.get("fixes") and not f.get("ignored")]
if not findings:
    print("no fixable findings"); sys.exit(0)

# --- bucket by (ident, disposition) ------------------------------------------
buckets = defaultdict(list)
fixable_audits = set()
for f in findings:
    fixable_audits.add(f["ident"])
    for disp in {fx["disposition"] for fx in f["fixes"]}:
        buckets[(f["ident"], disp)].append(f)

# --- repo's own config (preserve their ignore/disable policy) -----------------
repo_cfg = {}
for p in (".github/zizmor.yml", ".github/zizmor.yaml", "zizmor.yml", "zizmor.yaml"):
    if os.path.exists(p):
        repo_cfg = yaml.safe_load(open(p)) or {}
        break

def scoped_config(target):
    """repo config + disable every OTHER fixable audit (temp file, not in repo)."""
    cfg   = dict(repo_cfg)
    rules = dict(cfg.get("rules") or {})
    for a in fixable_audits:
        if a != target:
            r = dict(rules.get(a) or {}); r["disable"] = True; rules[a] = r
    cfg["rules"] = rules
    tf = tempfile.NamedTemporaryFile("w", suffix=".yml", delete=False)
    yaml.safe_dump(cfg, tf); tf.close()
    return tf.name

def loc(f):
    l = f["locations"][0]
    path = l["symbolic"]["key"]["Local"]["verbatim_path"]
    row  = l["concrete"]["location"]["start_point"]["row"] + 1   # json-v1 is 0-based
    return f"{path}:{row}"

def pr_body(ident, disp, fs):
    out = [f"Automated fixes for `{ident}` findings by [zizmor](https://docs.zizmor.sh).", ""]
    if disp == "unsafe":
        out += ["> ⚠️ **Unsafe fixes — review carefully before merging.**", ""]
    out.append("Resolves:")
    for f in fs:
        d = f["determinations"]
        out.append(f"- **{f['ident']}** ({d['severity']}/{d['confidence']}) at `{loc(f)}` — [docs]({f['url']})")
    out += ["", "_Prototype: regenerated each run. Do not hand-edit._"]
    return "\n".join(out)

# --- one PR per bucket -------------------------------------------------------
for (ident, disp), fs in buckets.items():
    try:
        branch = f"zizmor-autofix/{ident}" + ("" if disp == "safe" else "-unsafe")
        sh(["git", "checkout", "-f", BASE]); sh(["git", "reset", "--hard"])
        cfg = scoped_config(ident)
        sh(["zizmor", "--config", cfg, f"--fix={FIX_MODE[disp]}", "."])

        if sh(["git", "diff", "--quiet"]).returncode == 0:
            print(f"{ident}/{disp}: no changes"); continue

        sh(["git", "switch", "-C", branch], check=True)
        sh(["git", "add", "-A"], check=True)
        titles = "; ".join(sorted({fx["title"] for f in fs for fx in f["fixes"]
                                   if fx["disposition"] == disp}))
        sh(["git", "-c", "user.name=zizmor-autofix",
            "-c", "user.email=zizmor-autofix@users.noreply.github.com",
            "commit", "-m", f"zizmor: fix {ident} ({disp})\n\n{titles}"], check=True)
        sh(["git", "push", f"https://x-access-token:{TOKEN}@github.com/{REPO}.git",
            f"HEAD:refs/heads/{branch}", "--force"], check=True)

        body  = pr_body(ident, disp, fs)
        label = "safe-fix" if disp == "safe" else "needs-review"
        exists = sh(["gh", "pr", "list", "--head", branch, "--json", "number",
                     "-q", ".[0].number"], capture_output=True, text=True).stdout.strip()
        if exists:
            sh(["gh", "pr", "edit", branch, "--body", body])
        else:
            sh(["gh", "pr", "create", "--head", branch, "--base", BASE,
                "--title", f"zizmor: fix {ident} ({disp})", "--body", body, "--label", label])
        print(f"{ident}/{disp}: PR ready ({branch})")
    except subprocess.CalledProcessError as e:
        print(f"{ident}/{disp}: FAILED — {e}")
        continue