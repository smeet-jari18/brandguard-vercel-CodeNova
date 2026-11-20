from concurrent.futures import ThreadPoolExecutor
import httpx
import jwt

from app import auth_service, config, database, storage
from app.storage import STORE_LOCK, read_json, write_json


def test_supabase_token_cache_pools_and_evicts_on_logout(client, monkeypatch):
    auth_service.clear_supabase_cache()
    monkeypatch.setattr(config, "AUTH_PROVIDER", "supabase")
    monkeypatch.setattr(config, "SUPABASE_URL", "https://mock-project.supabase.co")
    monkeypatch.setattr(config, "SUPABASE_PUBLISHABLE_KEY", "mock-publishable")

    token = jwt.encode(
        {"sub": "perf-u1", "session_id": "perf-sid-1", "exp": 9999999999},
        "perf-test-secret-key-0123456789abcdef",
        algorithm="HS256",
    )
    remote = {
        "id": "perf-u1",
        "email": "perf@example.com",
        "user_metadata": {"name": "Perf User"},
        "app_metadata": {"brandguard_role": "creator"},
    }
    user_calls = []

    class _FakePool:
        def request(self, method, url, **kwargs):
            if url.endswith("/user") and method == "GET":
                user_calls.append(url)
                return httpx.Response(200, request=httpx.Request(method, url), json=remote)
            return httpx.Response(200, request=httpx.Request(method, url), json={})

    monkeypatch.setattr(auth_service, "_supabase_http", _FakePool())
    headers = {"Authorization": f"Bearer {token}"}

    # First call warms the cache + writes users profile once; subsequent reads hit cache.
    assert client.get("/api/v1/analytics", headers=headers).status_code == 200
    assert client.get("/api/v1/notifications", headers=headers).status_code == 200
    assert client.get("/api/v1/system/status", headers=headers).status_code == 200
    assert len(user_calls) == 1

    # /api/v1/auth/me always verifies live metadata.
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 200
    assert len(user_calls) == 2

    # Logout immediately revokes and evicts cache.
    assert client.post("/api/v1/auth/logout", headers=headers).status_code == 200
    assert client.get("/api/v1/analytics", headers=headers).status_code == 401
    auth_service.clear_supabase_cache()


def test_supabase_profile_skips_redundant_users_table_rewrites(client, monkeypatch):
    remote = {
        "id": "u-unchanged",
        "email": "same@example.com",
        "user_metadata": {"name": "Same Name"},
        "app_metadata": {"brandguard_role": "creator"},
    }
    writes = []
    orig_write = database.write

    def spy_write(name, value):
        writes.append(name)
        return orig_write(name, value)

    monkeypatch.setattr(storage, "db_write", spy_write)
    auth_service.supabase_profile(remote, sync_db=True)
    auth_service.supabase_profile(remote, sync_db=True)
    auth_service.supabase_profile(remote, sync_db=True)
    assert writes.count("users") == 1


def test_get_reviews_batches_rule_and_fact_reads(client, headers, monkeypatch):
    creator_headers = headers["creator"]
    reviewer_headers = headers["reviewer"]
    for i in range(5):
        res = client.post(
            "/api/v1/brand/check",
            headers=creator_headers,
            json={"brand_name": "Acme", "content": f"Clean compliant draft number {i}."},
        )
        assert res.status_code == 200

    reads = []
    orig_read = database.read

    def spy_read(name, default):
        reads.append(name)
        return orig_read(name, default)

    monkeypatch.setattr(storage, "db_read", spy_read)
    resp = client.get("/api/v1/reviews", headers=reviewer_headers)
    assert resp.status_code == 200
    assert resp.json()["total"] >= 5
    # Rules and facts are loaded once per request, never once per review record.
    assert reads.count("brand_rules") <= 1
    assert reads.count("library_facts") <= 1


def test_nonlocking_reads_coexist_with_serialized_writes(client):
    p = config.DATA_DIR / "perf_counter.json"
    write_json(p, {"count": 0})

    def step(i):
        if i % 2 == 0:
            with STORE_LOCK:
                cur = read_json(p, {"count": 0})
                write_json(p, {"count": cur["count"] + 1})
        else:
            val = read_json(p, {"count": 0})
            assert isinstance(val["count"], int)

    with ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(step, range(40)))
    assert read_json(p, {"count": 0})["count"] == 20
