export const MAX_PLAYERS = 6;
export function canJoinRoom({ members, sessionId, inviteValid }) {
  if (!inviteValid || typeof sessionId !== "string" || !sessionId) return false;
  if (!(members instanceof Set)) return false;
  // A live session ID cannot be used to claim an extra seat.\n  // Reconnection must use Colyseus' authenticated reconnect token instead.\n  return !members.has(sessionId) && members.size < MAX_PLAYERS;
}
export function registerMember(members, sessionId, inviteValid) {
  if (!canJoinRoom({ members, sessionId, inviteValid })) return false;
  members.add(sessionId);
  return true;
}
export function unregisterMember(members, sessionId) {
  return members.delete(sessionId);
}
