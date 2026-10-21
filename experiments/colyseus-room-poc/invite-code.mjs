import { timingSafeEqual } from "node:crypto";
export function validInviteCode(expected, supplied) {
  if (typeof expected !== "string" || typeof supplied !== "string") return false;
  const a = Buffer.from(expected, "utf8");
  const b = Buffer.from(supplied, "utf8");
  return a.length >= 12 && a.length === b.length && timingSafeEqual(a, b);
}
