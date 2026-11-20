from fastapi import APIRouter, Depends, HTTPException

from app import config
from app.approval.store import get_record, load_records
from app.auth import can_read, get_user, require_read_access
from app.receipts.store import get_receipt, load_receipts
from app.rules_store.store import (
    diff_rules_snapshot,
    get_brand_rule_versions,
    load_rule_store,
)
from app.storage import read_json

router = APIRouter(prefix="/api/v1/receipts", tags=["Processing Receipts"])


def _users_map() -> dict[str, dict]:
    return {
        u.get("user_id"): u
        for u in read_json(config.DATA_DIR / "users.json", [])
        if u.get("user_id")
    }


def receipt_view(
    receipt,
    record,
    *,
    rule_store: dict | None = None,
    users_by_id: dict[str, dict] | None = None,
):
    rules = get_brand_rule_versions(record["brand_name"], store=rule_store)
    current_rules = rules["current_version"] if rules else None
    current = (
        receipt.get("content_version") == record.get("content_version")
        and receipt["content_hash"] == record["content_hash"]
    )
    rules_current = receipt.get("rules_version") == current_rules
    rule_changes = []
    if not rules_current:
        diff = diff_rules_snapshot(
            brand_name=record["brand_name"],
            approved_brand_rules_version=receipt.get("rules_version"),
            approved_rule_versions=receipt.get("active_rule_versions"),
            channel=receipt.get("channel", "all"),
            store=rule_store,
        )
        rule_changes = diff["rule_changes"]

    users = users_by_id if users_by_id is not None else _users_map()
    creator_id = receipt.get("creator_id") or record.get("creator_id")
    creator_profile = users.get(creator_id, {}) if creator_id else {}
    creator_name = (
        receipt.get("creator_name")
        or record.get("creator_name")
        or creator_profile.get("name")
        or creator_profile.get("email")
        or creator_id
    )
    creator_email = (
        receipt.get("creator_email")
        or record.get("creator_email")
        or creator_profile.get("email")
        or ""
    )
    reviewer_id = receipt.get("reviewer") or record.get("reviewer")
    reviewer_profile = users.get(reviewer_id, {}) if reviewer_id else {}
    reviewer_name = (
        receipt.get("reviewer_name")
        or record.get("reviewer_name")
        or reviewer_profile.get("name")
        or reviewer_profile.get("email")
        or reviewer_id
    )
    reviewer_email = (
        receipt.get("reviewer_email")
        or record.get("reviewer_email")
        or reviewer_profile.get("email")
        or ""
    )

    return {
        **receipt,
        "creator_name": creator_name,
        "creator_email": creator_email,
        "reviewer_name": reviewer_name,
        "reviewer_email": reviewer_email,
        "is_current_version": current,
        "rules_current": rules_current,
        "rule_changes": rule_changes,
        "current_review_status": record["status"],
        "approval_valid": current and rules_current and record["status"] == "approved",
    }


@router.get("/")
def list_receipts(user: dict = Depends(get_user)):
    raw_receipts = load_receipts()
    if not raw_receipts:
        return {"total": 0, "receipts": []}
    records_by_id = {r["check_id"]: r for r in load_records()}
    rule_store = load_rule_store()
    users_by_id = _users_map()
    visible = []
    for receipt in raw_receipts:
        record = records_by_id.get(receipt["check_id"])
        if record is not None and can_read(record, user):
            visible.append(
                receipt_view(
                    receipt,
                    record,
                    rule_store=rule_store,
                    users_by_id=users_by_id,
                )
            )
    visible.sort(key=lambda r: r.get("timestamp") or "", reverse=True)
    return {"total": len(visible), "receipts": visible}


@router.get("/{receipt_id}")
def receipt_details(receipt_id: str, user: dict = Depends(get_user)):
    receipt = get_receipt(receipt_id)
    record = get_record(receipt["check_id"]) if receipt else None
    if receipt is None or record is None:
        raise HTTPException(404, "Processing receipt not found.")
    require_read_access(record, user)
    return receipt_view(receipt, record, users_by_id=_users_map())
