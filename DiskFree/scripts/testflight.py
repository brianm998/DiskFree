#!/usr/bin/env python3
"""Hand an uploaded Mac App Store build to TestFlight groups.

Waits for App Store Connect to finish processing the build, sets "What to
Test", adds the build to the named beta groups and, when any of them is
external, submits it for Beta App Review.

Credentials come from APPLE_API_KEY_PATH, APPLE_API_KEY_ID and
APPLE_API_ISSUER_ID. Needs PyJWT[crypto] at run time (not for the tests).
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE_URL = "https://api.appstoreconnect.apple.com"
WHATS_NEW_LIMIT = 4000
LOCALE = "en-US"


class TestFlightError(Exception):
    pass


def make_token(key_path, key_id, issuer_id):
    import jwt  # imported here so tests do not need PyJWT

    with open(key_path) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer_id, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


class AppStoreConnectClient:
    """Small JSON:API client. Paths may be absolute URLs (links.next)."""

    def __init__(self, token_fn, base_url=BASE_URL):
        self.token_fn = token_fn
        self.base_url = base_url

    def _request(self, method, path, params=None, body=None):
        url = path if path.startswith("http") else self.base_url + path
        if params:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", "Bearer " + self.token_fn())
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:1000]
            raise TestFlightError("%s %s failed: HTTP %d %s" % (method, url, e.code, detail))
        return json.loads(raw) if raw else {}

    def get(self, path, params=None):
        """GET and follow links.next, returning the merged 'data' list
        (or the single object for non-list responses)."""
        doc = self._request("GET", path, params)
        data = doc.get("data")
        if not isinstance(data, list):
            return data
        items = list(data)
        nxt = (doc.get("links") or {}).get("next")
        while nxt:
            doc = self._request("GET", nxt)
            items.extend(doc.get("data") or [])
            nxt = (doc.get("links") or {}).get("next")
        return items

    def post(self, path, body):
        return self._request("POST", path, body=body)

    def patch(self, path, body):
        return self._request("PATCH", path, body=body)


def wait_for_build(client, app_id, version, build_number, timeout, interval, sleep, clock):
    deadline = clock() + timeout
    while True:
        builds = client.get("/v1/builds", {
            "filter[app]": app_id,
            "filter[version]": build_number,
            "filter[preReleaseVersion.version]": version,
            "filter[preReleaseVersion.platform]": "MAC_OS",
        })
        if builds:
            build = builds[0]
            state = build["attributes"].get("processingState")
            if state == "VALID":
                return build
            if state in ("FAILED", "INVALID"):
                raise TestFlightError(
                    "Build %s (%s) processing ended in state %s" % (version, build_number, state))
            print("Build processing state: %s" % state, flush=True)
        else:
            print("Build %s (%s) not visible yet" % (version, build_number), flush=True)
        if clock() + interval > deadline:
            raise TestFlightError(
                "Timed out after %d s waiting for build %s (%s) to finish processing"
                % (timeout, version, build_number))
        sleep(interval)


def set_whats_new(client, build_id, text):
    text = text[:WHATS_NEW_LIMIT]
    locs = client.get("/v1/builds/%s/betaBuildLocalizations" % build_id)
    for loc in locs:
        if loc["attributes"].get("locale") == LOCALE:
            client.patch("/v1/betaBuildLocalizations/" + loc["id"], {"data": {
                "type": "betaBuildLocalizations", "id": loc["id"],
                "attributes": {"whatsNew": text}}})
            return
    client.post("/v1/betaBuildLocalizations", {"data": {
        "type": "betaBuildLocalizations",
        "attributes": {"locale": LOCALE, "whatsNew": text},
        "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})


def distribute(client, bundle_id, version, build_number, whats_new, group_names,
               timeout=1800, interval=30, sleep=time.sleep, clock=time.monotonic):
    apps = client.get("/v1/apps", {"filter[bundleId]": bundle_id})
    if not apps:
        raise TestFlightError("No app with bundle ID %s" % bundle_id)
    app_id = apps[0]["id"]

    groups = {g["attributes"]["name"]: g for g in client.get("/v1/apps/%s/betaGroups" % app_id)}
    missing = [n for n in group_names if n not in groups]
    if missing:
        raise TestFlightError("TestFlight group(s) not found: %s (existing: %s)"
                              % (", ".join(missing), ", ".join(sorted(groups)) or "none"))
    selected = [groups[n] for n in group_names]

    build = wait_for_build(client, app_id, version, build_number, timeout, interval, sleep, clock)
    build_id = build["id"]
    if build["attributes"].get("usesNonExemptEncryption") is None:
        raise TestFlightError(
            "Build is VALID but usesNonExemptEncryption is unset; export compliance is "
            "unanswered. Check INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO.")

    if whats_new.strip():
        set_whats_new(client, build_id, whats_new.strip())

    for g in selected:
        existing = client.get("/v1/betaGroups/%s/builds" % g["id"])
        if any(b["id"] == build_id for b in existing):
            print("Build already in group %s" % g["attributes"]["name"])
            continue
        client.post("/v1/betaGroups/%s/relationships/builds" % g["id"],
                    {"data": [{"type": "builds", "id": build_id}]})
        print("Added build to group %s" % g["attributes"]["name"])

    if any(not g["attributes"].get("isInternalGroup") for g in selected):
        subs = client.get("/v1/betaAppReviewSubmissions", {"filter[build]": build_id})
        if subs:
            print("Beta App Review submission already exists; skipping")
        else:
            client.post("/v1/betaAppReviewSubmissions", {"data": {
                "type": "betaAppReviewSubmissions",
                "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
            print("Submitted build for Beta App Review")
    return build_id


def parse_groups(values):
    names = []
    for v in values:
        names.extend(p.strip() for p in v.split(",") if p.strip())
    return names


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--version", required=True)
    p.add_argument("--build-number", required=True)
    p.add_argument("--whats-new", default="")
    p.add_argument("--whats-new-file")
    p.add_argument("--group", action="append", default=[], help="repeatable or comma-separated")
    p.add_argument("--bundle-id", default="com.DiskFree")
    p.add_argument("--timeout", type=int, default=1800)
    p.add_argument("--poll-interval", type=int, default=30)
    args = p.parse_args(argv)

    groups = parse_groups(args.group)
    if not groups:
        p.error("at least one --group is required")
    text = args.whats_new
    if args.whats_new_file:
        with open(args.whats_new_file) as f:
            text = f.read()
    try:
        key_path = os.environ["APPLE_API_KEY_PATH"]
        key_id = os.environ["APPLE_API_KEY_ID"]
        issuer = os.environ["APPLE_API_ISSUER_ID"]
    except KeyError as e:
        print("error: missing environment variable %s" % e, file=sys.stderr)
        return 2
    client = AppStoreConnectClient(lambda: make_token(key_path, key_id, issuer))
    try:
        distribute(client, args.bundle_id, args.version, args.build_number, text, groups,
                   args.timeout, args.poll_interval)
    except TestFlightError as e:
        print("error: %s" % e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
