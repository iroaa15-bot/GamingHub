export const MAX_PLAYERS = 6;
export function canJoinRoom({ members, sessionId, inviteValid }) {
  if (!inviteValid || typeof sessionId !== "string" || !sessionId) return false;
  if (!(members instanceof Set)) return false;
  return members.has(sessionId) || members.size < MAX_PLAYERS;
}
export function registerMember(members, sessionId, inviteValid) {
  if (!canJoinRoom({ members, sessionId, inviteValid })) return false;
  members.add(sessionId);
  return true;
}
export function unregisterMember(members, sessionId) {
  return members.delete(sessionId);
}
