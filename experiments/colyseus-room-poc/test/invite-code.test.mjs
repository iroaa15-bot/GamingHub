import test from "node:test";
import assert from "node:assert/strict";
import { validInviteCode } from "../invite-code.mjs";
test("correct invite accepted", () => assert.equal(validInviteCode("long-secret-1234", "long-secret-1234"), true));
test("incorrect invite rejected", () => assert.equal(validInviteCode("long-secret-1234", "incorrect-code-1"), false));
test("short invite rejected", () => assert.equal(validInviteCode("short", "short"), false));
test("missing invite rejected", () => assert.equal(validInviteCode("long-secret-1234", undefined), false));
test("unicode invite supported", () => assert.equal(validInviteCode("غرفة-تجربة-سرية", "غرفة-تجربة-سرية"), true));
