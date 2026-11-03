import pytest
from identity_backend.session_bindings import BoundIdentity, SessionBindings, verify_session
from identity_backend.app import initialize, app
from fastapi.testclient import TestClient
import os

def test_session_binding_from_database():
    initialize()
    client=TestClient(app)
    response=client.post("/api/auth/guest")
    assert response.status_code==201
    token=response.json()["access_token"]
    identity=verify_session(os.environ["GAMINGHUB_DATABASE_URL"],token)
    assert identity is not None
    socket=object()
    bindings=SessionBindings()
    with pytest.raises(ValueError):
        bindings.bind_verified(socket,"client-claimed-id")
    bindings.bind_verified(socket,identity)
    assert bindings.account_for(socket)==identity.user_id
    bindings.disconnect(socket)
    assert bindings.account_for(socket) is None
    assert verify_session(os.environ["GAMINGHUB_DATABASE_URL"],"not-a-token") is None
