from identity_backend.match_awards import award_from_finished

def test_authoritative_winner_mapping():
    accounts = ["account-one","account-two"]
    award = award_from_finished("ROOM123",{"type":"finished","winner":1},accounts)
    assert award.match_id=="ROOM123"
    assert award.user_id=="account-two"
    assert award.points==10

def test_draw_and_invalid_claims_not_awarded():
    accounts=["account-one","account-two"]
    for event in [
        {"type":"finished","winner":-1},
        {"type":"finished","winner":2},
        {"type":"finished","winner":"1"},
        {"type":"guess","winner":0},
        {"type":"finished","winner":True},
    ]:
        assert award_from_finished("ROOM123",event,accounts) is None
    assert award_from_finished("ROOM123",{"type":"finished","winner":0},["",None]) is None
