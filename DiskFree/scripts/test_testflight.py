import unittest

import testflight as tf


def build(state="VALID", enc=False):
    return {"id": "b1", "attributes": {"processingState": state, "usesNonExemptEncryption": enc}}


class FakeClient:
    def __init__(self, builds=(), groups=None, locs=(), subs=(), group_builds=()):
        self.builds = list(builds)  # successive poll responses (lists)
        self.groups = groups if groups is not None else [
            {"id": "gi", "attributes": {"name": "Internal", "isInternalGroup": True}},
            {"id": "ge", "attributes": {"name": "Ext", "isInternalGroup": False}}]
        self.locs, self.subs, self.group_builds = list(locs), list(subs), list(group_builds)
        self.calls = []

    def get(self, path, params=None):
        self.calls.append(("GET", path))
        if path == "/v1/apps":
            return [{"id": "app1"}]
        if path.endswith("/betaGroups"):
            return self.groups
        if path == "/v1/builds":
            return self.builds.pop(0) if len(self.builds) > 1 else self.builds[0]
        if path.endswith("/betaBuildLocalizations"):
            return self.locs
        if path == "/v1/betaAppReviewSubmissions":
            return self.subs
        if path.endswith("/builds"):
            return self.group_builds
        raise AssertionError(path)

    def post(self, path, body):
        self.calls.append(("POST", path, body))

    def patch(self, path, body):
        self.calls.append(("PATCH", path, body))

    def writes(self, method, path):
        return [c for c in self.calls if c[0] == method and c[1] == path]


class Clock:
    def __init__(self):
        self.t = 0

    def __call__(self):
        return self.t

    def sleep(self, s):
        self.t += s


def run(client, groups, text="notes", timeout=100, clock=None):
    clock = clock or Clock()
    return tf.distribute(client, "com.DiskFree", "1.0", "5.1", text, groups,
                         timeout, 10, clock.sleep, clock)


class Tests(unittest.TestCase):
    def test_polls_until_valid(self):
        c = FakeClient(builds=[[], [build("PROCESSING")], [build()]])
        clock = Clock()
        run(c, ["Internal"], clock=clock)
        self.assertEqual(clock.t, 20)
        self.assertEqual(len(c.writes("POST", "/v1/betaGroups/gi/relationships/builds")), 1)

    def test_timeout(self):
        c = FakeClient(builds=[[build("PROCESSING")]])
        with self.assertRaisesRegex(tf.TestFlightError, "Timed out"):
            run(c, ["Internal"], timeout=35)

    def test_failed_and_invalid(self):
        for s in ("FAILED", "INVALID"):
            with self.assertRaisesRegex(tf.TestFlightError, s):
                run(FakeClient(builds=[[build(s)]]), ["Internal"])

    def test_missing_group_fails_before_polling(self):
        c = FakeClient(builds=[[build()]])
        with self.assertRaisesRegex(tf.TestFlightError, "Nope"):
            run(c, ["Nope"])
        self.assertFalse(c.writes("GET", "/v1/builds"))

    def test_internal_only_no_submission(self):
        c = FakeClient(builds=[[build()]])
        run(c, ["Internal"])
        self.assertFalse(c.writes("POST", "/v1/betaAppReviewSubmissions"))
        self.assertFalse(c.writes("GET", "/v1/betaAppReviewSubmissions"))

    def test_external_submits(self):
        c = FakeClient(builds=[[build()]])
        run(c, ["Internal", "Ext"])
        self.assertEqual(len(c.writes("POST", "/v1/betaAppReviewSubmissions")), 1)

    def test_existing_submission_skipped(self):
        c = FakeClient(builds=[[build()]], subs=[{"id": "s1"}])
        run(c, ["Ext"])
        self.assertFalse(c.writes("POST", "/v1/betaAppReviewSubmissions"))

    def test_whats_new_post_then_patch(self):
        c = FakeClient(builds=[[build()]])
        run(c, ["Internal"])
        self.assertEqual(len(c.writes("POST", "/v1/betaBuildLocalizations")), 1)
        c = FakeClient(builds=[[build()]], locs=[{"id": "l1", "attributes": {"locale": "en-US"}}])
        run(c, ["Internal"])
        self.assertEqual(len(c.writes("PATCH", "/v1/betaBuildLocalizations/l1")), 1)

    def test_whats_new_truncated(self):
        c = FakeClient(builds=[[build()]])
        run(c, ["Internal"], text="x" * 5000)
        body = c.writes("POST", "/v1/betaBuildLocalizations")[0][2]
        self.assertEqual(len(body["data"]["attributes"]["whatsNew"]), 4000)

    def test_null_encryption_flag(self):
        c = FakeClient(builds=[[build(enc=None)]])
        with self.assertRaisesRegex(tf.TestFlightError, "usesNonExemptEncryption"):
            run(c, ["Internal"])

    def test_already_in_group_not_readded(self):
        c = FakeClient(builds=[[build()]], group_builds=[{"id": "b1"}])
        run(c, ["Internal"])
        self.assertFalse(c.writes("POST", "/v1/betaGroups/gi/relationships/builds"))

    def test_parse_groups(self):
        self.assertEqual(tf.parse_groups(["A, B", "C"]), ["A", "B", "C"])


if __name__ == "__main__":
    unittest.main()
