"""
KWS Portfolio Bridge API
========================
Host this on Render.com (free tier).
- MT4 EA POSTs account data every 30s  →  /api/update
- data_bridge.py GETs latest data      →  /api/accounts
- Simple API key authentication on both endpoints
"""

from flask import Flask, request, jsonify
from datetime import datetime
import os
import json

app = Flask(__name__)

# In-memory store: { account_label: { ...data... } }
# Render free tier spins down after inactivity — data resets on spin-up.
# MT4 EA re-populates within 30s automatically. This is acceptable.
_store = {}

API_KEY = os.environ.get("KWS_API_KEY", "changeme")


def _auth(req):
    return req.headers.get("X-KWS-Key") == API_KEY


# ── Health check (no auth) ───────────────────────────────────────────────────
@app.route("/")
def health():
    return jsonify({
        "status": "KWS Portfolio Bridge API running",
        "accounts": list(_store.keys()),
        "server_time": datetime.utcnow().isoformat() + "Z"
    })


# ── MT4 EA pushes data here ──────────────────────────────────────────────────
@app.route("/api/update", methods=["POST"])
def update():
    if not _auth(request):
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"error": "No JSON body"}), 400

    label = data.get("account_label")
    if not label:
        return jsonify({"error": "Missing account_label"}), 400

    _store[label] = {
        **data,
        "last_updated": datetime.utcnow().isoformat() + "Z"
    }

    return jsonify({"status": "ok", "account": label}), 200


# ── data_bridge.py polls here ────────────────────────────────────────────────
@app.route("/api/accounts", methods=["GET"])
def accounts():
    if not _auth(request):
        return jsonify({"error": "Unauthorized"}), 401

    return jsonify({
        "status": "ok",
        "count": len(_store),
        "accounts": _store
    }), 200


# ── Single account lookup ────────────────────────────────────────────────────
@app.route("/api/accounts/<label>", methods=["GET"])
def account(label):
    if not _auth(request):
        return jsonify({"error": "Unauthorized"}), 401

    if label not in _store:
        return jsonify({"error": f"Account '{label}' not found"}), 404

    return jsonify(_store[label]), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
