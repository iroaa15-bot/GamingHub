import test from "node:test";
import assert from "node:assert/strict";
import { validInviteCode } from "../invite-code.mjs";
import { canJoinRoom, registerMember, MAX_PLAYERS } from "../room-policy.mjs";
import { ReconnectReservations } from "../reconnect-policy.mjs";

test("invite code rejects prefix and trailing whitespace", () => {
  assert.equal(validInviteCode("room-secret-12345", "room-secret-1234"), false);
  assert.equal(validInviteCode("room-secret-12345", "room-secret-12345 "), false);
});
test("invalid member collections fail closed", () => {
  assert.equal(canJoinRoom({members:[],sessionId:"p1",inviteValid:true}),false);
  assert.equal(canJoinRoom({members:null,sessionId:"p1",inviteValid:true}),false);
});
test("denied join does not mutate members", () => {
  const members = new Set(Array.from({length:MAX_PLAYERS},(_,i)=>`p${i}`));
  assert.equal(registerMember(members,"attacker",true),false);
  assert.equal(members.size,MAX_PLAYERS);
  assert.equal(members.has("attacker"),false);
});
test("reconnect at exact deadline is expired", () => {
  let now=0;
  const reservations=new ReconnectReservations({now:()=>now});
  for(let i=0;i<6;i++) reservations.join(`p${i}`);
  reservations.disconnect("p0");
  now=90_000;
  assert.equal(reservations.join("new"),true);
  assert.equal(reservations.join("p0"),false);
});
test("unknown disconnect cannot reserve a slot", () => {
  const reservations=new ReconnectReservations();
  assert.equal(reservations.disconnect("stranger"),false);
  assert.equal(reservations.reserved.size,0);
});
