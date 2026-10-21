import test from "node:test";
import assert from "node:assert/strict";
import { ReconnectReservations } from "../reconnect-policy.mjs";
test("reconnect within 90 seconds reclaims reserved slot", () => {
 let now=0; const p=new ReconnectReservations({now:()=>now});
 assert.equal(p.join("a"),true); assert.equal(p.disconnect("a"),true);
 now=89_999; assert.equal(p.join("a"),true);
 assert.equal(p.active.has("a"),true); assert.equal(p.reserved.size,0);
});
test("reservation blocks a seventh player", () => {
 const p=new ReconnectReservations();
 for(let i=0;i<6;i++) assert.equal(p.join(`p${i}`),true);
 p.disconnect("p0"); assert.equal(p.join("p6"),false);
 assert.equal(p.join("p0"),true);
});
test("reservation expires after 90 seconds", () => {
 let now=0; const p=new ReconnectReservations({now:()=>now});
 for(let i=0;i<6;i++) p.join(`p${i}`);
 p.disconnect("p0"); now=90_000;
 assert.equal(p.join("p6"),true);
 assert.equal(p.join("p0"),false);
});
test("explicit leave releases slot immediately", () => {
 const p=new ReconnectReservations();
 for(let i=0;i<6;i++) p.join(`p${i}`);
 assert.equal(p.leave("p0"),true);
 assert.equal(p.join("p6"),true);
});
test("invalid and duplicate sessions do not consume slots", () => {
 const p=new ReconnectReservations();
 assert.equal(p.join(""),false); assert.equal(p.join("a"),true);
 assert.equal(p.join("a"),true); assert.equal(p.active.size,1);
});
