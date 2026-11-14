"""Separate historical provider links without copying ranked points or progress."""
import uuid


def independent_provider_user(db, user_id, provider, subject):
    # Different provider tokens for the same old account must serialize on the
    # account, not only on their different provider subjects.
    owner = db.execute(
        "SELECT display_name,password_hash FROM identity_users WHERE id=%s FOR UPDATE",
        (user_id,),
    ).fetchone()
    links = db.execute(
        "SELECT provider,subject FROM identity_providers WHERE user_id=%s ORDER BY provider FOR UPDATE",
        (user_id,),
    ).fetchall()
    # A password account keeps its own progress. Otherwise Google keeps the old
    # account when present; this is deterministic regardless of login order.
    keeper = None if owner[1] else ("google" if any(p == "google" for p, _ in links)
                                   else (links[0][0] if links else None))
    moved = False
    for linked_provider, linked_subject in links:
        if linked_provider == keeper:
            continue
        separate_id = str(uuid.uuid4())
        db.execute("INSERT INTO identity_users(id,display_name) VALUES(%s,%s)",
                   (separate_id, owner[0]))
        db.execute("UPDATE identity_providers SET user_id=%s WHERE provider=%s AND subject=%s",
                   (separate_id, linked_provider, linked_subject))
        moved = True
    if moved:
        # Old sessions did not record which provider authenticated them. They
        # cannot safely remain valid after separation. The current verified
        # login receives a fresh session after this transaction.
        db.execute("UPDATE identity_sessions SET revoked=TRUE WHERE user_id=%s", (user_id,))
        db.execute("UPDATE identity_refresh_sessions SET revoked=TRUE WHERE user_id=%s", (user_id,))
    # Re-read after locking: a concurrent login may have moved this link while
    # this transaction was waiting for the historical account lock.
    return db.execute("SELECT user_id FROM identity_providers WHERE provider=%s AND subject=%s",
                      (provider, subject)).fetchone()[0]
