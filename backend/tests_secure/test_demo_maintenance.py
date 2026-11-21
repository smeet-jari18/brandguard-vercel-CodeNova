"""Demo setup regression tests: explicit destructive scope and genuine API seeding."""
import copy
import json
from pathlib import Path

import pytest
from sqlalchemy import select

import demo_admin as admin
from app.database import TRANSACTION, _current, entities, write


def row(collection, entity_id, **payload):
    return {"collection": collection, "entity_id": entity_id, "position": 0, "payload": payload}


def sample():
    return {"format": "brandguard-db-v1", "documents": [], "entities": [
        row("review_records", "a", check_id="a", status="pending"),
        row("receipts", "ra", receipt_id="ra", check_id="a"),
        row("notifications", "na", id="na", check_id="a"),
        row("review_records", "b", check_id="b", status="approved", seal_id="sb"),
        row("approval_seals", "sb", seal_id="sb", check_id="b"),
        row("audit_log", "audit", audit_id="audit", check_id="a"),
        row("assets", "asset", id="asset", creator_id="u1"),
        row("auth_users", "u1", user_id="u1"),
    ]}


def test_cleanup_closure_preserves_audit_files_and_other_users():
    plan = admin.make_plan(sample(), {"check_ids": ["a"]})
    assert {x["entity_id"] for x in plan["delete"]} == {"a", "ra", "na"}
    assert plan["blockers"] == []
    assert plan["reviewed_check_ids"] == []


def test_reviewed_requires_explicit_acknowledgement():
    assert admin.make_plan(sample(), {"check_ids": ["b"]})["reviewed_check_ids"] == ["b"]


@pytest.mark.parametrize("selection", [{"check_ids": ["unknown"]}, {"users": ["u1"]}, {"draft_ids": ["missing"]}])
def test_unknown_or_disallowed_ids_rejected(selection):
    with pytest.raises(ValueError):
        admin.make_plan(sample(), selection)


def test_retained_parent_and_shared_ticket_block_cleanup():
    snap = sample()
    snap["entities"].append(row("review_records", "child", check_id="child", parent_check_id="a"))
    snap["entities"].append(row("clarity_tickets", "ticket", ticket_id="ticket", sample_overrides=[{"check_id": "a"}, {"check_id": "b"}]))
    plan = admin.make_plan(snap, {"check_ids": ["a"]})
    assert {b["id"] for b in plan["blockers"]} == {"child", "ticket"}


def test_private_output_never_overwrites(tmp_path):
    path = tmp_path / "secret.json"
    admin.private_write(path, {"a": 1})
    with pytest.raises(FileExistsError):
        admin.private_write(path, {"a": 2})
    assert json.loads(path.read_text()) == {"a": 1}


def test_apply_backups_and_rejects_stale_plan(client, tmp_path):
    write("review_records", [{"check_id": "test-only", "status": "pending"}])
    with TRANSACTION:
        snap = admin.snapshot(_current.get()["conn"])
    plan = admin.make_plan(snap, {"check_ids": ["test-only"]})
    path = tmp_path / "plan.json"
    admin.private_write(path, plan)
    backup = tmp_path / "backup.json"
    admin.apply_plan(path, backup, plan["snapshot_sha256"], False)
    saved = admin.read(backup)
    assert saved["format"] == "brandguard-db-v1"
    assert any(r["entity_id"] == "test-only" for r in saved["entities"])
    with TRANSACTION:
        after = admin.snapshot(_current.get()["conn"])
    assert not any(r["entity_id"] == "test-only" for r in after["entities"])
    assert any(r["collection"] == "audit_log" and r["payload"]["action"] == "admin_demo_cleanup" for r in after["entities"])
    with pytest.raises(ValueError, match="changed"):
        admin.apply_plan(path, tmp_path / "backup2.json", plan["snapshot_sha256"], False)
    assert not (tmp_path / "backup2.json").exists()


def test_apply_refuses_reviewed_without_ack(client, tmp_path):
    write("review_records", [{"check_id": "reviewed", "status": "approved"}])
    with TRANSACTION:
        plan = admin.make_plan(admin.snapshot(_current.get()["conn"]), {"check_ids": ["reviewed"]})
    path = tmp_path / "plan.json"; admin.private_write(path, plan)
    with pytest.raises(ValueError, match="Reviewed"):
        admin.apply_plan(path, tmp_path / "backup.json", plan["snapshot_sha256"], False)
    assert not (tmp_path / "backup.json").exists()


@pytest.mark.parametrize("with_assets", [False, True])
def test_seed_real_workflow_and_safe_rerun(client, monkeypatch, tmp_path, with_assets):
    # Reuse the isolated app transport; no live network or database is touched.
    import httpx
    class Transport:
        def request(self, method, path, **kw):
            return client.request(method, path, **kw)
        def close(self):
            pass
    monkeypatch.setattr(httpx, "Client", lambda **kw: Transport())
    monkeypatch.setattr(admin, "getpass", lambda prompt: "Demo@12345")
    state = tmp_path / "state.json"
    args = ("http://127.0.0.1:8000", state, "creator@brandguard.demo", "reviewer@brandguard.demo", "http://127.0.0.1:8000", with_assets, True)
    admin.seed(*args)
    data = admin.read(state)
    assert data["last_verification"]["valid"] is True
    steps = data["steps"]
    assert {"acme-check", "acme-decision", "zest-check", "skyline-draft"} <= set(steps)
    assert steps["skyline-draft"]["brand_name"] == "Skyline Travel"
    admin.seed(*args)
    with TRANSACTION:
        snap = admin.snapshot(_current.get()["conn"])
    checks = [r["payload"] for r in snap["entities"] if r["collection"] == "review_records"]
    policy = next(d['payload'] for d in snap['documents'] if d['name'] == 'brand_rules')
    for brand in ('acme', 'zest foods', 'skyline travel'):
        b = policy['brands'][brand]
        assert len(b['versions'][b['current_version']]['rules']) == 4
    assert len(policy['brands']['acme']['versions']['1.0.0']['rules']) == 5
    assert len(checks) == 2
    zest = next(r for r in checks if r['brand_name'] == 'Zest Foods')
    assert {'ZEST-003', 'ZEST-004'} <= {f['rule_id'] for f in zest['findings']}
    assert len([r for r in snap['entities'] if r['collection'] == 'assets']) == (2 if with_assets else 0)
    assert {r["status"] for r in checks} == {"approved", "pending"}
    assert len([r for r in snap["entities"] if r["collection"] == "drafts"]) == 1
    assert len([r for r in snap["entities"] if r["collection"] == "library_guidelines"]) == 3
    fresh = client.post('/api/v1/auth/signup', json={'name': 'Fresh User', 'email': 'fresh@example.test', 'password': 'FreshOnly123!'}).json()
    fresh_headers = {'Authorization': 'Bearer ' + fresh['access_token']}
    assert client.get('/api/v1/history', headers=fresh_headers).json()['total'] == 0
    assert client.get('/api/v1/drafts', headers=fresh_headers).json()['total'] == 0
    assert client.get('/api/v1/library/rules?brand_name=Zest%20Foods', headers=fresh_headers).json()['total'] == 4
    receipt = steps['acme-check']['receipt_id']
    assert client.get('/api/v1/receipts/' + receipt, headers=fresh_headers).status_code in {403, 404}
    assert client.patch('/api/v1/reviews/' + steps['zest-check']['check_id'] + '/decision', headers=fresh_headers, json={'decision': 'approved'}).status_code == 403


def test_all_catalog_matchers_and_clean_copy(client, headers):
    import regex
    from app.routers.library import LibraryItem
    catalog = admin.read(admin.CATALOG)["brands"]
    for brand in catalog:
        for rule in brand["rules"]:
            LibraryItem(**rule)
            assert rule["rule_quote"] in rule["rule_text"]
            assert not regex.search(rule["pattern"], brand["clean_copy"], flags=regex.I)
            phrase = {"ACME-001": "free forever", "ACME-002": "best in the world", "ACME-003": "guaranteed results", "ACME-004": "100% secure", "ZEST-001": "cure diabetes", "ZEST-002": "guaranteed weight loss", "ZEST-003": "zero sugar", "ZEST-004": "100% organic", "SKY-001": "guaranteed visa approval", "SKY-002": "100% refund", "SKY-003": "lowest price guaranteed", "SKY-004": "free cancellation anytime"}[rule["rule_id"]]
            assert regex.search(rule["pattern"], phrase, flags=regex.I)


def test_seed_refuses_uncertain_mutation_before_login(tmp_path):
    state = tmp_path / "state.json"
    admin.private_write(state, {"origin": "https://example.com", "creator_email": "c", "reviewer_email": "r", "steps": {}, "inflight": {"step": "acme-check"}})
    with pytest.raises(ValueError, match="uncertain"):
        admin.seed("https://example.com", state, "c", "r", "https://example.com")
