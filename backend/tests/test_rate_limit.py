"""Rate limit per user endpoint AI: biar satu orang gak ngabisin kuota Groq bareng."""
import pytest

from app.core import rate_limit as rl
from app.core.config import settings


class _Clock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now


def test_parse_limits():
    assert rl.parse_limits("6/minute, 40/hours") == [(6, 60.0), (40, 3600.0)]
    assert rl.parse_limits("") == []


def test_sliding_window_blocks_then_frees_up():
    clock = _Clock()
    limiter = rl.RateLimiter(clock)
    limits = [(2, 60.0)]

    assert limiter.hit("snap", 1, limits) is None
    clock.now += 10
    assert limiter.hit("snap", 1, limits) is None
    clock.now += 5
    # mentok: hit pertama (t=1000) baru keluar jendela di t=1060 -> nunggu 45 dtk
    assert limiter.hit("snap", 1, limits) == pytest.approx(45)
    # request yg ditolak gak ikut dihitung, user lain & bucket lain gak kena
    assert limiter.hit("snap", 2, limits) is None
    assert limiter.hit("chat", 1, limits) is None

    clock.now = 1061
    assert limiter.hit("snap", 1, limits) is None


def test_longer_window_also_enforced():
    clock = _Clock()
    limiter = rl.RateLimiter(clock)
    limits = [(5, 60.0), (6, 3600.0)]
    for _ in range(6):
        assert limiter.hit("ai", 1, limits) is None
        clock.now += 61  # selalu lolos batas per menit
    wait = limiter.hit("ai", 1, limits)
    assert wait is not None and wait > 3000  # mentok batas per jam


@pytest.mark.asyncio
async def test_endpoint_returns_429_with_retry_after(auth_client, monkeypatch):
    monkeypatch.setattr(settings, "rate_limit_chat", "2/minute")
    for _ in range(2):
        resp = await auth_client.post("/ai/chat/message", json={"message": "halo"})
        assert resp.status_code == 200

    resp = await auth_client.post("/ai/chat/message", json={"message": "halo lagi"})
    assert resp.status_code == 429
    assert int(resp.headers["retry-after"]) >= 1
    assert "Coba lagi dalam" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_rate_limit_can_be_disabled(auth_client, monkeypatch):
    monkeypatch.setattr(settings, "rate_limit_chat", "1/minute")
    monkeypatch.setattr(settings, "rate_limit_enabled", False)
    for _ in range(3):
        resp = await auth_client.post("/ai/chat/message", json={"message": "halo"})
        assert resp.status_code == 200


@pytest.mark.asyncio
async def test_non_ai_endpoints_not_limited(auth_client, monkeypatch):
    monkeypatch.setattr(settings, "rate_limit_ai", "1/minute")
    for _ in range(3):
        assert (await auth_client.get("/ai/chat/history")).status_code == 200
        assert (await auth_client.get("/tasks")).status_code == 200
