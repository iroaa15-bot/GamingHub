import test from "node:test";
import assert from "node:assert/strict";
import { MAX_PLAYERS, canJoinRoom, registerMember, unregisterMember } from "../room-policy.mjs";

test("reject unauthorized and malformed sessions", () => {
  assert.equal(canJoinRoom({members:new Set(),sessionId:"p1",inviteValid:false}),false);
  assert.equal(canJoinRoom({members:new Set(),sessionId:"",inviteValid:true}),false);
});
test("allow six players, reject seventh", () => {
  const members=new Set();
  for(let i=0;i<MAX_PLAYERS;i++) assert.equal(registerMember(members,`p${i}`,true),true);
  assert.equal(registerMember(members,"p6",true),false);
  assert.equal(members.size,6);
});
test("allow replacement after player leaves", () => {
  const members=new Set(Array.from({length:6},(_,i)=>`p${i}`));
  assert.equal(unregisterMember(members,"p0"),true);
  assert.equal(registerMember(members,"p6",true),true);
  assert.equal(members.size,6);
});
test("idempotent re-entry for existing session", () => {
  const members=new Set(Array.from({length:6},(_,i)=>`p${i}`));
  assert.equal(registerMember(members,"p1",true),true);
  assert.equal(members.size,6);
});
