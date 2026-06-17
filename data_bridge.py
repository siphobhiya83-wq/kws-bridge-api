"""
KWS Portfolio Bridge — data_bridge.py (v2)
==========================================
Pulls live account data from the KWS Bridge API hosted on Render.
Replaces local JSON file reading.

Fallback chain:
  1. KWS Bridge API (MT4 accounts via VPS push)
  2. MT5 direct Python connection (MT5 accounts e.g. Mrs Mqadi)
  3. Demo seed data (if both above unavailable)

Place your API URL and key in config.py:
  KWS_BRIDGE_API_URL = "https://YOUR-APP.onrender.com"
  KWS_BRIDGE_API_KEY = "your_api_key_here"
"""

import requests
import time
import logging
from datetime import datetime
from typing import Optional

logger = logging.getLogger(__name__)

# ── Config import (never edit config.py) ────────────────────────────────────
try:
    from config import KWS_BRIDGE_API_URL, KWS_BRIDGE_API_KEY
except ImportError:
    KWS_BRIDGE_API_URL = None
    KWS_BRIDGE_API_KEY = None
    logger.warning("config.py missing KWS_BRIDGE_API_URL / KWS_BRIDGE_API_KEY — API bridge disabled")

# ── MT5 direct connection (for Mrs Mqadi MT5 account) ───────────────────────
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
except ImportError:
    MT5_AVAILABLE = False
    logger.info("MetaTrader5 package not available — MT5 direct bridge disabled")

# ── Cache to avoid hammering the API ────────────────────────────────────────
_cache = {}
_cache_ts = 0
CACHE_TTL = 25  # seconds (EA pushes every 30s, so 25s keeps us fresh)


# ── Main public function ─────────────────────────────────────────────────────
def get_all_accounts() -> dict:
    """
    Returns dict of all known accounts with their latest data.
    Format: { "account_label": { account_data } }
    """
    accounts = {}

    # Layer 1: KWS Bridge API (MT4 accounts via VPS)
    api_accounts = _fetch_from_api()
    if api_accounts:
        accounts.update(api_accounts)

    # Layer 2: MT5 direct (Mrs Mqadi and any other MT5 accounts)
    mt5_accounts = _fetch_from_mt5()
    if mt5_accounts:
        accounts.update(mt5_accounts)

    # Layer 3: Demo fallback if nothing else available
    if not accounts:
        logger.warning("No live data sources available — using demo seed data")
        accounts = _demo_seed()

    return accounts


def get_account(label: str) -> Optional[dict]:
    """Get a single account by label."""
    all_accounts = get_all_accounts()
    return all_accounts.get(label)


# ── Layer 1: KWS Bridge API ──────────────────────────────────────────────────
def _fetch_from_api() -> dict:
    global _cache, _cache_ts

    if not KWS_BRIDGE_API_URL or not KWS_BRIDGE_API_KEY:
        return {}

    # Return cached data if fresh
    if time.time() - _cache_ts < CACHE_TTL and _cache:
        return _cache

    try:
        url = f"{KWS_BRIDGE_API_URL.rstrip('/')}/api/accounts"
        headers = {"X-KWS-Key": KWS_BRIDGE_API_KEY}
        resp = requests.get(url, headers=headers, timeout=8)

        if resp.status_code == 200:
            data = resp.json()
            accounts = data.get("accounts", {})
            _cache = accounts
            _cache_ts = time.time()
            logger.info(f"KWS API: fetched {len(accounts)} account(s)")
            return accounts
        else:
            logger.warning(f"KWS API returned HTTP {resp.status_code}")
            return _cache  # return stale cache on error

    except requests.exceptions.ConnectionError:
        logger.warning("KWS API unreachable — Render may be spinning up (cold start ~30s)")
        return _cache
    except Exception as e:
        logger.error(f"KWS API error: {e}")
        return _cache


# ── Layer 2: MT5 Direct ──────────────────────────────────────────────────────
def _fetch_from_mt5() -> dict:
    """
    Directly connects to MT5 on this machine.
    Used for Mrs Mqadi's MT5 account.
    Add MT5 login credentials to config.py:
      MT5_ACCOUNTS = [
          {"login": 123456, "password": "xxx", "server": "Headway-Live", "label": "Mrs Mqadi"},
      ]
    """
    if not MT5_AVAILABLE:
        return {}

    try:
        from config import MT5_ACCOUNTS
    except ImportError:
        return {}

    results = {}

    for acct in MT5_ACCOUNTS:
        try:
            if not mt5.initialize(
                login=acct["login"],
                password=acct["password"],
                server=acct["server"]
            ):
                logger.warning(f"MT5 init failed for {acct['label']}: {mt5.last_error()}")
                continue

            info = mt5.account_info()
            if info is None:
                continue

            positions = mt5.positions_get()
            pos_list = []
            if positions:
                for p in positions:
                    pos_list.append({
                        "ticket": p.ticket,
                        "symbol": p.symbol,
                        "type": p.type,
                        "lots": p.volume,
                        "open_price": p.price_open,
                        "sl": p.sl,
                        "tp": p.tp,
                        "profit": p.profit,
                        "swap": p.swap,
                        "comment": p.comment
                    })

            results[acct["label"]] = {
                "account_label": acct["label"],
                "account_number": info.login,
                "balance": info.balance,
                "equity": info.equity,
                "margin": info.margin,
                "free_margin": info.margin_free,
                "profit": info.profit,
                "currency": info.currency,
                "leverage": info.leverage,
                "open_positions": len(pos_list),
                "positions": pos_list,
                "platform": "MT5",
                "last_updated": datetime.utcnow().isoformat() + "Z"
            }

            mt5.shutdown()
            logger.info(f"MT5 direct: fetched {acct['label']}")

        except Exception as e:
            logger.error(f"MT5 fetch error for {acct.get('label', '?')}: {e}")

    return results


# ── Layer 3: Demo seed ───────────────────────────────────────────────────────
def _demo_seed() -> dict:
    return {
        "DEMO — Mrs Mqadi": {
            "account_label": "DEMO — Mrs Mqadi",
            "balance": 1500.00,
            "equity": 1487.50,
            "profit": -12.50,
            "currency": "USD",
            "open_positions": 2,
            "positions": [],
            "platform": "DEMO",
            "last_updated": datetime.utcnow().isoformat() + "Z"
        },
        "DEMO — Thembi Dhlomo (TeacherD1)": {
            "account_label": "DEMO — Thembi Dhlomo (TeacherD1)",
            "balance": 1281.66,
            "equity": 1295.00,
            "profit": 13.34,
            "currency": "USD",
            "open_positions": 3,
            "positions": [],
            "platform": "DEMO",
            "last_updated": datetime.utcnow().isoformat() + "Z"
        }
    }
