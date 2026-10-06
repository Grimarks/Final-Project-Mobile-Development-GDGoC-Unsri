"""Rate limit per user buat endpoint yg manggil Groq. Kuota free tier Groq itu
bareng-bareng satu API key, jadi satu user yg spam (atau rame2 di booth) bisa
bikin AI-nya mati buat semua orang.

Sliding window di memori: cukup buat satu proses uvicorn (start-server.command).
Kalo nanti jalan multi-worker / multi-server, pindahin ke Redis."""
from __future__ import annotations

import math
import time
from collections import defaultdict, deque
from collections.abc import Callable

from fastapi import Depends, HTTPException, status

from app.core.config import settings
from app.core.security import get_current_user
from app.models.user import User

_UNITS = {"second": 1, "minute": 60, "hour": 3600, "day": 86400}


def parse_limits(spec: str) -> list[tuple[int, float]]:
    """ "6/minute,40/hour" -> [(6, 60), (40, 3600)]. Kosong = gak dibatesin."""
    limits = []
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        count, unit = part.split("/")
        limits.append((int(count), float(_UNITS[unit.strip().rstrip("s")])))
    return limits


class RateLimiter:
    def __init__(self, clock: Callable[[], float] = time.monotonic) -> None:
        self._clock = clock
        self._hits: dict[tuple[str, int], deque[float]] = defaultdict(deque)

    def hit(self, bucket: str, user_id: int, limits: list[tuple[int, float]]) -> float | None:
        """Catet 1 request. Balikin None kalo boleh, atau berapa detik lagi mesti nunggu
        kalo udah mentok — request yg ditolak gak ikut dicatet."""
        if not limits:
            return None
        now = self._clock()
        hits = self._hits[(bucket, user_id)]
        longest = max(window for _, window in limits)
        while hits and hits[0] <= now - longest:
            hits.popleft()  # buang yg udah di luar jendela terpanjang

        wait = 0.0
        for count, window in limits:
            in_window = [t for t in hits if t > now - window]
            if len(in_window) >= count:
                # baru boleh lagi pas hit tertua yg masih ngitung keluar jendela
                wait = max(wait, in_window[-count] + window - now)
        if wait > 0:
            return wait
        hits.append(now)
        return None

    def reset(self) -> None:
        self._hits.clear()


limiter = RateLimiter()


def rate_limit(bucket: str) -> Callable:
    """Dependency: `dependencies=[Depends(rate_limit("snap"))]` di route-nya."""

    async def check(user: User = Depends(get_current_user)) -> None:
        if not settings.rate_limit_enabled:
            return
        wait = limiter.hit(bucket, user.id, parse_limits(settings.rate_limit_for(bucket)))
        if wait is not None:
            seconds = max(1, math.ceil(wait))
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS,
                f"Terlalu banyak permintaan AI. Coba lagi dalam {seconds} detik.",
                headers={"Retry-After": str(seconds)},
            )

    return check
