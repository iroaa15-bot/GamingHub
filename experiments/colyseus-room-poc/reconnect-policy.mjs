// Offline reservation policy only; not wired to Colyseus.
export class ReconnectReservations {
  constructor({ graceMs = 90_000, maxPlayers = 6, now = () => Date.now() } = {}) {
    this.graceMs = graceMs;
    this.maxPlayers = maxPlayers;
    this.now = now;
    this.active = new Set();
    this.reserved = new Map();
  }
  cleanup() {
    const time = this.now();
    for (const [id, until] of this.reserved) if (until <= time) this.reserved.delete(id);
  }
  join(id) {
    this.cleanup();
    if (!id || typeof id !== "string") return false;
    if (this.active.has(id)) return true;
    if (this.reserved.has(id)) { this.reserved.delete(id); this.active.add(id); return true; }
    if (this.active.size + this.reserved.size >= this.maxPlayers) return false;
    this.active.add(id);
    return true;
  }
  disconnect(id) {
    if (!this.active.delete(id)) return false;
    this.reserved.set(id, this.now() + this.graceMs);
    return true;
  }
  leave(id) { return this.active.delete(id) || this.reserved.delete(id); }
}
