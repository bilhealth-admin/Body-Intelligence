#!/usr/bin/env python3
"""Local-only real PostgreSQL+PostgREST HTTP/JWT integration test."""
from __future__ import annotations
import base64
import hashlib
import hmac
import json
import os
import time
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:3002"
SECRET = b"bil07-fixture-only-jwt-secret-48chars-and-nothing-live"
A = "35000000-0000-4000-8000-000000000001"
B = "35000000-0000-4000-8000-000000000002"
C = "35000000-0000-4000-8000-000000000003"
PUBLIC = "35000000-0000-4000-8000-000000000010"
PRIVATE = "35000000-0000-4000-8000-000000000011"
KEY = "35000000-0000-4000-8000-000000000111"


def _encode(data):
    return base64.urlsafe_b64encode(
        json.dumps(data, separators=(",", ":")).encode()
    ).decode().rstrip("=")


def jwt(owner, *, consent=True):
    header = _encode({"alg": "HS256", "typ": "JWT"})
    payload = _encode({
        "role": "authenticated", "sub": owner,
        "fixture_community_consent": "true" if consent else "false",
        "exp": int(time.time()) + 1800,
    })
    part = (header + "." + payload).encode()
    signature = base64.urlsafe_b64encode(
        hmac.new(SECRET, part, hashlib.sha256).digest()
    ).decode().rstrip("=")
    return header + "." + payload + "." + signature


def request(rpc_name, data=None, *, owner=None, consent=True):
    assert rpc_name.startswith("bil07_"), "Only synthetic BIL07 RPCs allowed"
    headers = {"Content-Type": "application/json"}
    if owner:
        headers["Authorization"] = "Bearer " + jwt(owner, consent=consent)
    req = urllib.request.Request(
        BASE + "/rpc/" + rpc_name, method="POST",
        headers=headers, data=json.dumps(data or {}).encode(),
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status, body = response.status, response.read(200_000)
    except urllib.error.HTTPError as exc:
        status, body = exc.code, exc.read(200_000)
    return status, json.loads(body) if body else None


def check(value, description):
    if not value:
        raise AssertionError(description)


def allowed(rpc_name, data, owner):
    status, payload = request(rpc_name, data, owner=owner)
    check(status == 200, f"{rpc_name}: expected 200, got {status}: {payload}")
    check(isinstance(payload, dict), f"{rpc_name}: missing JSON")
    check(payload.get("owner_id", payload.get("reviewer_id")) == owner,
          f"{rpc_name}: wrong authenticated owner")
    return payload


def denied(rpc_name, data, owner=None, consent=True):
    status, payload = request(rpc_name, data, owner=owner, consent=consent)
    check(status in (401, 403, 404),
          f"{rpc_name}: expected denied, got {status}: {payload}")


def wait_server():
    for _ in range(45):
        try:
            with urllib.request.urlopen(BASE + "/", timeout=2):
                return
        except urllib.error.HTTPError as exc:
            if exc.code in (400, 401, 404):
                return
        except urllib.error.URLError:
            pass
        time.sleep(1)
    raise RuntimeError("PostgREST did not start in the isolated runner")


def main():
    check(os.getenv("BIL07_FIXTURE_HTTP_ONLY") == "1", "Fixture opt-in missing")
    wait_server()
    denied("bil07_channel_capabilities_v1", {})
    cap = allowed("bil07_channel_capabilities_v1", {}, A)
    check(cap["contract_version"] == 1 and cap["max_text_code_points"] == 2000,
          "mobile capability v1 mismatch")
    check(cap["realtime_available"] is False, "unapproved realtime enabled")
    directory = allowed("bil07_channel_directory_v1",
                        {"p_after_id": None, "p_limit": 50}, A)
    check(len(directory["channels"]) == 1
          and directory["channels"][0]["id"] == PUBLIC,
          "member-only channel visible outside membership")
    denied("bil07_channel_messages_v1", {
        "p_channel_id": PRIVATE, "p_before_sequence": None,
        "p_after_sequence": None, "p_limit": 50,
    }, A)
    denied("bil07_channel_send_v1", {
        "p_channel_id": PUBLIC, "p_client_message_id": KEY,
        "p_text": "Missing fixture consent",
    }, A, consent=False)
    content = "Synthetic message for safety review"
    payload = {"p_channel_id": PUBLIC, "p_client_message_id": KEY,
               "p_text": content}
    first = allowed("bil07_channel_send_v1", payload, A)
    check(first["idempotent_replay"] is False, "original send marked replay")
    msg = first["message"]
    second = allowed("bil07_channel_send_v1", payload, A)
    check(second["idempotent_replay"] is True
          and second["message"]["id"] == msg["id"],
          "duplicate send or changed message identity")
    code, _ = request("bil07_channel_send_v1",
                      {**payload, "p_text": "Altered text"}, owner=A)
    check(code == 400, "changed payload was accepted as idempotent")
    reader = allowed("bil07_channel_directory_v1",
                     {"p_after_id": None, "p_limit": 50}, B)
    check(len(reader["channels"]) == 2, "member could not read private room")
    item = next(v for v in reader["channels"] if v["id"] == PUBLIC)
    check(item["unread_count"] == 1, "unread count not owner-scoped")
    messages = allowed("bil07_channel_messages_v1", {
        "p_channel_id": PUBLIC, "p_before_sequence": None,
        "p_after_sequence": None, "p_limit": 50}, B)
    check(len(messages["messages"]) == 1
          and messages["messages"][0]["is_read"] is False,
          "wrong B message view")
    allowed("bil07_channel_read_v1",
            {"p_channel_id": PUBLIC, "p_message_ids": [msg["id"]]}, B)
    receipt = allowed("bil07_channel_readback_v1",
                      {"p_channel_id": PUBLIC, "p_message_ids": [msg["id"]]}, B)
    check(receipt["unread_count"] == 0
          and msg["id"] in receipt["acknowledged_message_ids"],
          "read receipt was not persisted")
    denied("bil07_channel_read_v1",
           {"p_channel_id": PRIVATE, "p_message_ids": [msg["id"]]}, A)
    denied("bil07_channel_review_queue_v1", {"p_limit": 50}, B)
    denied("bil07_channel_report_v1", {
        "p_channel_id": PUBLIC, "p_message_id": msg["id"],
        "p_reason": "Self report"}, A)
    report_args = {"p_channel_id": PUBLIC, "p_message_id": msg["id"],
                   "p_reason": "Synthetic harassment"}
    report = allowed("bil07_channel_report_v1", report_args, B)
    check(report["idempotent_replay"] is False, "new report was duplicate")
    replay = allowed("bil07_channel_report_v1", report_args, B)
    check(replay["idempotent_replay"] is True
          and replay["report_id"] == report["report_id"],
          "report replay made duplicate")
    queue = allowed("bil07_channel_review_queue_v1", {"p_limit": 50}, C)
    check(len(queue["reports"]) == 1
          and queue["reports"][0]["message_id"] == msg["id"],
          "authorized moderator cannot see report")
    decision = allowed("bil07_channel_decide_report_v1", {
        "p_report_id": report["report_id"], "p_remove": True}, C)
    check(decision["decision_remove"] is True,
          "reviewer removal decision missing")
    hidden = allowed("bil07_channel_messages_v1", {
        "p_channel_id": PUBLIC, "p_before_sequence": None,
        "p_after_sequence": None, "p_limit": 50}, B)
    check(len(hidden["messages"]) == 0,
          "removed content leaked to another user")
    # These are real HTTP writes but solely to the disposable fixture. Twenty
    # messages are the sender's total minute budget (including first send).
    for index in range(19):
        request_key = "35000000-0000-4000-8000-" + format(1280 + index, "012x")
        allowed("bil07_channel_send_v1", {
            "p_channel_id": PUBLIC,
            "p_client_message_id": request_key,
            "p_text": "Synthetic sender throttle fixture",
        }, A)
    rate_status, _ = request("bil07_channel_send_v1", {
        "p_channel_id": PUBLIC,
        "p_client_message_id": "35000000-0000-4000-8000-000000000999",
        "p_text": "Synthetic flood must be rejected",
    }, owner=A)
    check(rate_status == 403, "21st unique send evaded owner rate cap")
    committed_retry = allowed("bil07_channel_send_v1", payload, A)
    check(committed_retry["idempotent_replay"] is True,
          "owner rate cap incorrectly blocks committed idempotent retry")
    allowed("bil07_channel_send_v1", {
        "p_channel_id": PUBLIC,
        "p_client_message_id": "35000000-0000-4000-8000-000000000901",
        "p_text": "Another owner's independent allowance",
    }, C)
    print("BIL07_REAL_POSTGRES_OWNER_RATE_LIMIT=PASS")
    print("BIL07_REAL_POSTGRES_POSTGREST_RLS=PASS")
    print("BIL07_REAL_POSTGRES_POSTGREST_REPORT_MODERATION=PASS")
    print("BIL07_REAL_POSTGRES_POSTGREST_OWNER_IDEMPOTENCY=PASS")
    print("BIL07_EPHEMERAL_FIXTURE_ONLY_NO_PRODUCTION_ACCESS=PASS")


if __name__ == "__main__":
    main()
