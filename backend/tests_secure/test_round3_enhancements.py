from io import BytesIO
from PIL import Image


def _png_bytes(color="#0F172A"):
    img = Image.new("RGB", (240, 120), color)
    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_receipt_exposes_creator_and_reviewer_names_and_emails(client, headers):
    created = client.post(
        "/api/v1/brand/check",
        headers=headers["creator"],
        json={
            "brand_name": "Acme",
            "content": "Acme launch copy verified for release.",
            "submit_for_review": True,
        },
    )
    assert created.status_code == 200, created.text
    check_id = created.json()["check_id"]
    receipt_id = created.json()["receipt_id"]

    # Before review: creator_name and creator_email are present.
    detail = client.get(f"/api/v1/receipts/{receipt_id}", headers=headers["creator"])
    assert detail.status_code == 200, detail.text
    body = detail.json()
    assert body["creator_email"] == "creator@brandguard.demo"
    assert body["creator_name"]
    assert body["creator_name"] != body["creator_id"]

    # After review: reviewer_name and reviewer_email are present too.
    decided = client.patch(
        f"/api/v1/reviews/{check_id}/decision",
        headers=headers["reviewer"],
        json={"decision": "approved", "note": "Looks clean"},
    )
    assert decided.status_code == 200, decided.text

    after = client.get(f"/api/v1/receipts/{receipt_id}", headers=headers["creator"]).json()
    assert after["reviewer_email"] == "reviewer@brandguard.demo"
    assert after["reviewer_name"]
    assert after["reviewer_name"] != after["reviewer"]

    listing = client.get("/api/v1/receipts/", headers=headers["creator"]).json()
    match = next(r for r in listing["receipts"] if r["receipt_id"] == receipt_id)
    assert match["creator_email"] == "creator@brandguard.demo"
    assert match["reviewer_email"] == "reviewer@brandguard.demo"


def test_delete_unreviewed_check_allowed_and_blocked_once_reviewed(client, headers):
    # 1. Draft check can be deleted by its owner.
    draft = client.post(
        "/api/v1/brand/check",
        headers=headers["creator"],
        json={
            "brand_name": "Acme",
            "content": "Temporary draft to delete.",
            "submit_for_review": False,
        },
    )
    assert draft.status_code == 200
    draft_id = draft.json()["check_id"]
    assert client.delete(f"/api/v1/brand/{draft_id}", headers=headers["reviewer"]).status_code == 403
    deleted_draft = client.delete(f"/api/v1/brand/{draft_id}", headers=headers["creator"])
    assert deleted_draft.status_code == 200, deleted_draft.text
    assert deleted_draft.json()["deleted"] is True

    # 2. Newly submitted pending check (not yet reviewed) can be deleted by owner.
    pending = client.post(
        "/api/v1/brand/check",
        headers=headers["creator"],
        json={
            "brand_name": "Acme",
            "content": "Pending check created by mistake.",
            "submit_for_review": True,
        },
    )
    assert pending.status_code == 200
    pending_id = pending.json()["check_id"]
    pending_receipt = pending.json()["receipt_id"]

    deleted_pending = client.delete(f"/api/v1/brand/{pending_id}", headers=headers["creator"])
    assert deleted_pending.status_code == 200, deleted_pending.text
    assert (
        client.get(f"/api/v1/receipts/{pending_receipt}", headers=headers["creator"]).status_code
        == 404
    )
    reviews_after = client.get("/api/v1/reviews", headers=headers["creator"]).json()["reviews"]
    assert all(r["check_id"] != pending_id for r in reviews_after)

    # 3. Once reviewed (changes_requested, approved, or rejected), deletion is blocked (409).
    reviewed = client.post(
        "/api/v1/brand/check",
        headers=headers["creator"],
        json={
            "brand_name": "Acme",
            "content": "Checked by reviewer.",
            "submit_for_review": True,
        },
    ).json()
    reviewed_id = reviewed["check_id"]
    assert (
        client.patch(
            f"/api/v1/reviews/{reviewed_id}/decision",
            headers=headers["reviewer"],
            json={"decision": "changes_requested", "note": "Add pricing clarity"},
        ).status_code
        == 200
    )
    blocked = client.delete(f"/api/v1/brand/{reviewed_id}", headers=headers["creator"])
    assert blocked.status_code == 409, blocked.text

    # Even if creator resubmits Rev 2, prior review decision history blocks deletion.
    assert (
        client.post(
            f"/api/v1/brand/{reviewed_id}/versions",
            headers=headers["creator"],
            json={"content": "Billed 49 dollars monthly.", "submit_for_review": True},
        ).status_code
        == 200
    )
    blocked_rev2 = client.delete(f"/api/v1/brand/{reviewed_id}", headers=headers["creator"])
    assert blocked_rev2.status_code == 409


def test_review_and_check_include_enriched_assets_for_reviewer_view_and_download(
    client, headers
):
    img_bytes = _png_bytes("#0F172A")
    img_res = client.post(
        "/api/v1/files",
        headers=headers["creator"],
        files={"file": ("campaign_banner.png", img_bytes, "image/png")},
    )
    assert img_res.status_code == 201, img_res.text
    img_id = img_res.json()["id"]

    txt_bytes = b"Verified pricing note for Q4 rollout."
    txt_res = client.post(
        "/api/v1/files",
        headers=headers["creator"],
        files={"file": ("campaign_notes.txt", txt_bytes, "text/plain")},
    )
    assert txt_res.status_code == 201, txt_res.text
    txt_id = txt_res.json()["id"]

    check = client.post(
        "/api/v1/brand/check",
        headers=headers["creator"],
        json={
            "brand_name": "Acme",
            "content": "Campaign ready with attachments.",
            "content_type": "multimodal",
            "asset_ids": [img_id, txt_id],
            "submit_for_review": True,
        },
    )
    assert check.status_code == 200, check.text
    check_body = check.json()
    assert len(check_body["assets"]) == 2
    assert check_body["assets"][0]["name"] == "campaign_banner.png"
    assert check_body["assets"][0]["is_image"] is True
    assert check_body["assets"][1]["name"] == "campaign_notes.txt"
    assert check_body["assets"][1]["is_image"] is False

    # Reviewer sees enriched asset list in GET /api/v1/reviews and can preview + download raw bytes.
    reviews = client.get("/api/v1/reviews", headers=headers["reviewer"]).json()["reviews"]
    row = next(r for r in reviews if r["check_id"] == check_body["check_id"])
    assert len(row["assets"]) == 2
    assert row["assets"][0]["name"] == "campaign_banner.png"
    assert row["assets"][0]["is_image"] is True
    assert row["assets"][1]["name"] == "campaign_notes.txt"

    img_dl = client.get(f"/api/v1/files/{img_id}/download", headers=headers["reviewer"])
    assert img_dl.status_code == 200
    assert img_dl.content == img_bytes

    txt_preview = client.get(f"/api/v1/files/{txt_id}", headers=headers["reviewer"])
    assert txt_preview.status_code == 200
    assert txt_preview.json()["extracted_text"] == txt_bytes.decode()
