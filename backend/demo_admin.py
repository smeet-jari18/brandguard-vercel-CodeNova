"""Trusted local/admin CLI. Never expose this tool as an HTTP endpoint.

inventory -> edit selection.json -> plan -> inspect plan -> apply (backup first).
seed uses existing Creator and Reviewer logins through genuine API workflows.
"""
import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from getpass import getpass
from pathlib import Path

from sqlalchemy import delete, select

from app import config
from app.database import TRANSACTION, _current, documents, entities
from app.audit.store import log_audit

ALLOWED = {"check_ids", "draft_ids", "notification_ids", "ticket_ids", "conflict_ids", "override_ids"}
DIRECT = {"drafts": "draft_ids", "notifications": "notification_ids", "clarity_tickets": "ticket_ids", "conflicts": "conflict_ids", "finding_overrides": "override_ids"}
DEPENDENTS = {"receipts", "approval_seals", "finding_overrides", "conflicts", "notifications"}
CATALOG = Path(__file__).parent / "demo" / "catalog.json"


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def private_write(path, value):
    path = Path(path).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def snapshot(conn):
    return {
        "format": "brandguard-db-v1",
        "entities": [dict(r) for r in conn.execute(select(entities).order_by(entities.c.collection, entities.c.entity_id)).mappings()],
        "documents": [dict(r) for r in conn.execute(select(documents).order_by(documents.c.name)).mappings()],
    }


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from strings(v)


def make_plan(snap, selection):
    if not isinstance(selection, dict) or set(selection) - ALLOWED:
        raise ValueError("Selection must contain only supported explicit ID arrays")
    if any(not isinstance(selection.get(k, []), list) or any(not isinstance(v, str) or not v for v in selection.get(k, [])) for k in ALLOWED):
        raise ValueError("Every selection value must be an array of nonempty string IDs")
    chosen = {k: set(selection.get(k, [])) for k in ALLOWED}
    rows = snap["entities"]
    checks = {r["entity_id"]: r for r in rows if r["collection"] == "review_records"}
    if chosen["check_ids"] - set(checks):
        raise ValueError("Unknown check IDs")
    for coll, key in DIRECT.items():
        available = {r["entity_id"] for r in rows if r["collection"] == coll}
        if chosen[key] - available:
            raise ValueError(f"Unknown IDs for {coll}")
    doomed = {(r["collection"], r["entity_id"]) for r in rows if
              (r["collection"] == "review_records" and r["entity_id"] in chosen["check_ids"]) or
              (r["collection"] in DIRECT and r["entity_id"] in chosen[DIRECT[r["collection"]]])}
    # Include known check-level dependent rows, including old versions' receipts/seals.
    changed = True
    while changed:
        changed = False
        ids = {eid for _, eid in doomed}
        for r in rows:
            pair = (r["collection"], r["entity_id"])
            if pair in doomed or r["collection"] not in DEPENDENTS:
                continue
            p = r["payload"]
            if p.get("check_id") in chosen["check_ids"] or (r["collection"] == "notifications" and p.get("check_id") in ids):
                doomed.add(pair)
                changed = True
    ids = {eid for _, eid in doomed}
    blockers = []
    # Fail closed on retained references, including shared tickets and parent chains.
    for r in rows:
        pair = (r["collection"], r["entity_id"])
        if pair in doomed or r["collection"] == "audit_log":
            continue
        refs = set(strings(r["payload"])) & ids
        if refs:
            blockers.append({"collection": pair[0], "id": pair[1], "references": sorted(refs)})
    for r in snap["documents"]:
        refs = set(strings(r["payload"])) & ids
        if refs:
            blockers.append({"document": r["name"], "references": sorted(refs)})
    reviewed = [cid for cid in sorted(chosen["check_ids"]) if
                checks[cid]["payload"].get("status") not in {"draft", "pending", "paused_conflict"} or
                any(checks[cid]["payload"].get(k) for k in ("decided_at", "decision_history", "seal_id"))]
    return {"format": "brandguard-cleanup-plan-v1", "snapshot_sha256": digest(snap),
            "selection": {k: sorted(v) for k, v in sorted(chosen.items())},
            "delete": [{"collection": c, "entity_id": eid} for c, eid in sorted(doomed)],
            "reviewed_check_ids": reviewed, "blockers": blockers,
            "preserved": ["audit history", "users and auth identities", "all stored files and asset metadata", "rules and fact history", "all unselected records"]}


def inventory(output):
    with TRANSACTION:
        snap = snapshot(_current.get()["conn"])
    summaries = []
    for row in snap["entities"]:
        if row["collection"] not in {"review_records", *DIRECT}:
            continue
        p = row["payload"]
        summaries.append({"collection": row["collection"], "entity_id": row["entity_id"],
                          **{k: p.get(k) for k in ("creator_id", "user_id", "brand_name", "status", "title", "check_id", "created_at")},
                          "preview": str(p.get("content") or p.get("message") or "")[:240]})
    policy = next((d['payload'] for d in snap['documents'] if d['name'] == 'brand_rules'), {})
    policy_summary = {}
    for name, brand in policy.get('brands', {}).items():
        current = brand.get('current_version')
        policy_summary[name] = {'current_version': current,
                                'rules': brand.get('versions', {}).get(current, {}).get('rules', [])}
    private_write(output, {"snapshot_sha256": digest(snap), "records": summaries,
                           "current_brand_policies_for_review": policy_summary,
                           "library_entries_for_manual_review": [r for r in snap['entities'] if r['collection'] in {'library_guidelines', 'library_facts'}],
                           "selection_template": {k: [] for k in sorted(ALLOWED)}})
    print("Private inventory written. Copy selection_template into a separate selection.json and add exact approved IDs.")


def apply_plan(path, backup, confirm, allow_reviewed):
    plan = read(path)
    if confirm != plan.get("snapshot_sha256"):
        raise ValueError("--confirm must equal the plan's snapshot_sha256")
    with TRANSACTION:
        conn = _current.get()["conn"]
        snap = snapshot(conn)
        if digest(snap) != plan.get("snapshot_sha256"):
            raise ValueError("Database changed. Generate and review a new plan; nothing deleted.")
        actual = make_plan(snap, plan["selection"])
        if actual != plan:
            raise ValueError("Database changed or plan was edited. Generate and review a new plan; nothing deleted.")
        if actual["blockers"]:
            raise ValueError("Retained objects reference selected data. Resolve blockers explicitly first.")
        if actual["reviewed_check_ids"] and not allow_reviewed:
            raise ValueError("Reviewed checks require explicit --allow-reviewed-test-records after owner approval")
        if not actual["delete"]:
            raise ValueError("Empty plan; nothing to delete")
        private_write(backup, snap | {"created_at": datetime.now(timezone.utc).isoformat()})
        # Backup is durable before the first DELETE. DB transaction rolls back on any error.
        for r in actual["delete"]:
            conn.execute(delete(entities).where(entities.c.collection == r["collection"], entities.c.entity_id == r["entity_id"]))
        log_audit("admin_demo_cleanup", "trusted-demo-admin", "demo-maintenance",
                  {"snapshot_sha256": actual["snapshot_sha256"], "deleted": actual["delete"], "audit_preserved": True})
    print(f"Deleted {len(actual['delete'])} approved database rows. Backup written; files, auth and prior audit history unchanged.")


def seed(base, state_path, creator_email, reviewer_email, confirm, with_assets=False, archive_extra_rules=False):
    import httpx
    from urllib.parse import urlparse
    parsed = urlparse(base)
    if parsed.scheme not in {"https", "http"} or not parsed.netloc or parsed.username or parsed.query or parsed.fragment or parsed.path not in {"", "/"}:
        raise ValueError("Use the backend origin only")
    if parsed.scheme != "https" and parsed.hostname not in {"localhost", "127.0.0.1"}:
        raise ValueError("Nonlocal seeding requires HTTPS")
    base = base.rstrip("/")
    if confirm != base:
        raise ValueError("--confirm-origin must exactly match the backend origin")
    state_file = Path(state_path)
    state = read(state_file) if state_file.exists() else {"origin": base, "creator_email": creator_email, "reviewer_email": reviewer_email, "with_assets": with_assets, "archive_extra_rules": archive_extra_rules, "steps": {}}
    if (state["origin"], state["creator_email"], state["reviewer_email"]) != (base, creator_email, reviewer_email):
        raise ValueError("State belongs to another environment/accounts")
    if state.get("with_assets", False) != with_assets:
        raise ValueError("Do not change --with-assets for an existing seed state")
    if state.get("archive_extra_rules", False) != archive_extra_rules:
        raise ValueError("Do not change --archive-extra-rules for an existing seed state")
    if state.get("inflight"):
        raise ValueError("A previous mutation has an uncertain outcome. Inspect the live records and reconcile inflight in the private state before resuming; do not blindly retry.")
    def save():
        # State never contains passwords/tokens. Atomic replacement, private permissions.
        tmp = state_file.with_name(state_file.name + ".tmp")
        if tmp.exists():
            raise ValueError("State temporary file exists; inspect it before retrying")
        private_write(tmp, state)
        os.replace(tmp, state_file)
    client = httpx.Client(base_url=base, timeout=90, follow_redirects=False)
    def call(method, path, token=None, **kw):
        response = client.request(method, path, headers={"Authorization": f"Bearer {token}"} if token else {}, **kw)
        if not response.is_success:
            # No request headers, passwords or response token data in error messages.
            raise ValueError(f"API {method} {path} failed: HTTP {response.status_code}. Check server logs securely.")
        return response.json()
    def mutate(step, method, path, token, **kw):
        if step in state["steps"]:
            return state["steps"][step]
        state["inflight"] = {"step": step, "method": method, "path": path}
        save()
        result = call(method, path, token, **kw)
        state["steps"][step] = result
        state.pop("inflight")
        save()
        return result
    creator = call("POST", "/api/v1/auth/login", json={"email": creator_email, "password": getpass("Creator password: ")})
    reviewer = call("POST", "/api/v1/auth/login", json={"email": reviewer_email, "password": getpass("Reviewer password: ")})
    if creator["user"].get("role") != "creator":
        raise ValueError("Use a dedicated Creator-role account for curated submissions")
    if creator["user"]["user_id"] == reviewer["user"]["user_id"] or reviewer["user"].get("role") not in {"reviewer", "admin"}:
        raise ValueError("Use two distinct users and a provisioned Reviewer")
    c, r = creator["access_token"], reviewer["access_token"]
    catalog = read(CATALOG)["brands"]
    # Refuse to silently add demo clutter to an existing Creator workspace.
    if not state["steps"]:
        history = call("GET", "/api/v1/history", c)
        drafts = call("GET", "/api/v1/drafts", c)
        if history.get("total", 0) or history.get("items") or drafts.get("items"):
            raise ValueError("Creator workspace is not empty. Finish approved cleanup or use a dedicated empty Creator.")
    save()
    for brand in catalog:
        name = brand["name"]
        rows = call("GET", "/api/v1/library/rules", r, params={"brand_name": name})["items"]
        current = {row["id"]: row for row in rows}
        extra = sorted(set(current) - {rule["rule_id"] for rule in brand["rules"]})
        if extra and not archive_extra_rules:
            raise ValueError(f"{name} has extra current rules: {extra}. Review them first. --archive-extra-rules removes them from the current version through the normal policy API, preserving historical versions.")
        for rid in extra:
            mutate("archive:" + name + ":" + rid, "DELETE", f"/api/v1/library/rules/{rid}", r, params={"brand_name": name})
        for rule in brand["rules"]:
            rid = rule["rule_id"]
            if rid in current:
                # Existing rules/history are never overwritten by this script.
                for key in ("pattern", "severity", "rule_text", "enabled"):
                    if current[rid].get(key) != rule[key]:
                        raise ValueError(f"Existing {rid} differs at {key}; review through normal policy versioning, not automatic overwrite")
            else:
                mutate("rule:" + rid, "POST", "/api/v1/library/rules", r, json=rule)
        guidelines = call("GET", "/api/v1/library/guidelines", r, params={"brand_name": name})["items"]
        match = next((g for g in guidelines if g["title"] == brand["guideline"]["title"]), None)
        if match and match.get("content") != brand["guideline"]["content"]:
            raise ValueError(f"Existing {name} guideline differs; review manually")
        if not match:
            mutate("guideline:" + name, "POST", "/api/v1/library/guidelines", r, json=brand["guideline"])
    # Validate actual active rule resolution/grounding, not just stored JSON.
    for brand in catalog:
        clean = call("POST", "/api/v1/brand/preflight", c,
                     json={"brand_name": brand["name"], "content": brand["clean_copy"]})
        if clean.get("findings") or clean.get("conflicts"):
            raise ValueError(f"Clean {brand['name']} sample has findings/conflicts under live policies. Inspect before seeding checks.")
        # This fixture covers all four exact phrases for each selected brand.
        probes = {
            "Acme": "free forever; best in the world; guaranteed results; 100% secure",
            "Zest Foods": "cure diabetes; guaranteed weight loss; zero sugar; 100% organic",
            "Skyline Travel": "guaranteed visa approval; 100% refund; lowest price guaranteed; free cancellation anytime",
        }
        checked = call("POST", "/api/v1/brand/preflight", c,
                       json={"brand_name": brand["name"], "content": probes[brand["name"]]})
        expected = {rule["rule_id"] for rule in brand["rules"]}
        if not expected <= {f["rule_id"] for f in checked.get("findings", [])}:
            raise ValueError(f"Active {brand['name']} policy did not detect all expected phrases; inspect dates, channels and grounding.")
    assets = {}
    if with_assets:
        for brand in catalog[:2]:
            image = Path(__file__).parent.parent / "demo_samples" / f"{brand['slug']}_campaign.png"
            with image.open("rb") as stream:
                uploaded = mutate("asset:" + brand["slug"], "POST", "/api/v1/files", c,
                                  params={"brand_name": brand["name"]},
                                  files={"file": (image.name, stream, "image/png")})
            assets[brand["name"]] = [uploaded["id"]]
    acme = mutate("acme-check", "POST", "/api/v1/brand/check", c, json={"brand_name": "Acme", "content": catalog[0]["clean_copy"], "asset_ids": assets.get("Acme", []), "submit_for_review": True})
    aid = acme["check_id"]
    if "acme-decision" not in state["steps"]:
        mutate("acme-decision", "PATCH", f"/api/v1/reviews/{aid}/decision", r,
               json={"decision": "approved", "note": "Reviewed fictional demonstration copy against the active Acme rules.", "expected_version": 1})
    mutate("zest-check", "POST", "/api/v1/brand/check", c, json={"brand_name": "Zest Foods", "content": "Discover Zest Foods: a 100% organic snack with zero sugar for your next break.", "asset_ids": assets.get("Zest Foods", []), "submit_for_review": True})
    mutate("skyline-draft", "POST", "/api/v1/drafts", c, json={"title": "Skyline Travel — Weekend Campaign Draft", "brand_name": "Skyline Travel", "content": catalog[2]["clean_copy"], "attachments": []})
    verification = call("POST", "/api/v1/approvals/verify", c, json={"check_id": aid, "brand_name": "Acme", "content": catalog[0]["clean_copy"], "asset_ids": assets.get("Acme", [])})
    state["last_verification"] = verification
    save()
    if not verification.get("valid"):
        raise ValueError("Seeded approval did not verify. Inspect last_verification in the private state; do not announce success.")
    client.close()
    print("Seed completed: Acme approved check, Zest pending check, Skyline saved draft. Inspect private state and verify both clients. No factual sources were invented. Optional assets are included only with --with-assets; inspect runtime OCR status separately.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    inv = sub.add_parser("inventory"); inv.add_argument("--out", required=True)
    plan = sub.add_parser("plan"); plan.add_argument("--selection", required=True); plan.add_argument("--out", required=True)
    apply = sub.add_parser("apply"); apply.add_argument("--plan", required=True); apply.add_argument("--backup", required=True); apply.add_argument("--confirm", required=True); apply.add_argument("--allow-reviewed-test-records", action="store_true")
    load = sub.add_parser("seed"); load.add_argument("--base-url", required=True); load.add_argument("--state", required=True); load.add_argument("--creator-email", required=True); load.add_argument("--reviewer-email", required=True); load.add_argument("--confirm-origin", required=True); load.add_argument("--with-assets", action="store_true"); load.add_argument("--archive-extra-rules", action="store_true")
    args = parser.parse_args()
    if args.command == "seed":
        return seed(args.base_url, args.state, args.creator_email, args.reviewer_email, args.confirm_origin, args.with_assets, args.archive_extra_rules)
    if config.STORAGE_BACKEND != "database":
        parser.error("Cleanup supports the SQL repository only; legacy JSON mode is intentionally refused")
    if args.command == "inventory":
        inventory(args.out)
    elif args.command == "plan":
        with TRANSACTION:
            result = make_plan(snapshot(_current.get()["conn"]), read(args.selection))
        private_write(args.out, result)
        print(f"Plan written: {len(result['delete'])} rows, {len(result['blockers'])} blockers; no deletions performed.")
    else:
        apply_plan(args.plan, args.backup, args.confirm, args.allow_reviewed_test_records)


if __name__ == "__main__":
    main()
