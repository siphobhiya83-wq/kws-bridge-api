# KWS Portfolio Bridge v2 — Deployment Guide
## From VPS → Cloud API → Lenovo Dashboard

---

## What You're Building

```
VPS (MT4)                        Render.com (free)           Lenovo
KWS_Portfolio_Bridge_v2.mq4  →  KWS Bridge API (Flask)  →  data_bridge.py
POST every 30s                   stores latest data           GET every 25s
                                                              ↓
                                                         Portfolio Dashboard
                                                         localhost:8503
```

---

## STEP 1 — Deploy the API to Render.com (one time, ~10 minutes)

### 1a. Put the API files on GitHub
Create a new GitHub repository called `kws-bridge-api`.
Upload these 3 files:
- `app.py`
- `requirements.txt`
- `Procfile`

### 1b. Create a free Render account
Go to https://render.com and sign up (free, no credit card needed).

### 1c. Create a new Web Service on Render
1. Click **New → Web Service**
2. Connect your GitHub repo `kws-bridge-api`
3. Settings:
   - **Name:** kws-bridge-api
   - **Runtime:** Python 3
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `gunicorn app:app`
   - **Instance Type:** Free

### 1d. Set the environment variable (your API key)
In Render dashboard → Environment → Add:
```
Key:   KWS_API_KEY
Value: KWSSecure2026!          ← change this to something private
```

### 1e. Deploy
Click **Deploy**. Wait ~2 minutes. You'll get a URL like:
```
https://kws-bridge-api.onrender.com
```

### 1f. Test it
Open in browser:
```
https://kws-bridge-api.onrender.com
```
You should see:
```json
{"status": "KWS Portfolio Bridge API running", "accounts": [], "server_time": "..."}
```
✓ API is live.

---

## STEP 2 — Update MT4 EA on VPS (~5 minutes)

### 2a. Copy the new EA to VPS
Copy `KWS_Portfolio_Bridge_v2.mq4` to your VPS at:
```
C:\Program Files (x86)\MetaTrader 4\MQL4\Experts\
```
(or wherever your MT4 Experts folder is)

### 2b. Compile in MetaEditor
Open MetaEditor → open `KWS_Portfolio_Bridge_v2.mq4` → press F7 to compile.
Should show: **0 errors, 0 warnings**

### 2c. Allow WebRequest in MT4
This is critical — MT4 blocks HTTP calls by default.
MT4 → Tools → Options → Expert Advisors tab:
- ✓ Check **Allow WebRequest for listed URL**
- Add: `https://kws-bridge-api.onrender.com`
- Click OK

### 2d. Attach the new EA to chart
Remove `KWS_Portfolio_Bridge_v1` from the chart first.
Drag `KWS_Portfolio_Bridge_v2` onto GBPUSD H1 (or any chart).

Set inputs:
```
AccountLabel  = Thembi Dhlomo (TeacherD1)
ApiUrl        = https://kws-bridge-api.onrender.com/api/update
ApiKey        = KWSSecure2026!        ← same as your Render env var
PushInterval  = 30
```
Click OK.

### 2e. Verify in Experts log
You should see within 30 seconds:
```
KWS Bridge v2: Pushed 11 position(s) for Thembi Dhlomo (TeacherD1)
```

### 2f. Verify in browser
Open:
```
https://kws-bridge-api.onrender.com
```
You should now see `"accounts": ["Thembi Dhlomo (TeacherD1)"]`

---

## STEP 3 — Update Lenovo: config.py and data_bridge.py (~5 minutes)

### 3a. Add to config.py on Lenovo
Open `config.py` in kws_portfolio folder.
Add these two lines:
```python
KWS_BRIDGE_API_URL = "https://kws-bridge-api.onrender.com"
KWS_BRIDGE_API_KEY = "KWSSecure2026!"
```

### 3b. Replace data_bridge.py
Replace the existing `data_bridge.py` in kws_portfolio with the new v2 file.

### 3c. Install requests if needed
```
cd C:\Users\msbhi\OneDrive\Desktop\KWS\kws_portfolio
venv\Scripts\activate
pip install requests
```

### 3d. Launch dashboard
```
run_portfolio.bat
```
Open http://localhost:8503
Thembi Dhlomo (TeacherD1) should appear with live data within 30 seconds.

---

## STEP 4 — Add Mrs Mqadi (MT5 account)

Add to `config.py`:
```python
MT5_ACCOUNTS = [
    {
        "login": 123456,          # ← Mrs Mqadi's MT5 account number
        "password": "xxxxx",      # ← her MT5 password
        "server": "Headway-Live", # ← exact server name from MT5
        "label": "Mrs Mqadi"
    }
]
```
The data_bridge.py v2 will connect directly to MT5 on the Lenovo
and pull her account data without needing any EA or VPS.

---

## Render Free Tier Notes

- Free tier **spins down after 15 minutes of inactivity**
- First request after spin-down takes ~30 seconds (cold start)
- MT4 EA pushes every 30s — this keeps Render awake during trading hours
- Outside trading hours the API sleeps — that's fine, no data to push
- Free tier gives 750 hours/month — more than enough for 24/5 forex

---

## Important Reminders

- NEVER share your `ApiKey` publicly
- NEVER commit `config.py` to GitHub
- Add `config.py` to `.gitignore` if you create a repo for kws_portfolio
- The `ApiKey` in the MT4 EA inputs is visible to anyone who opens the EA settings —
  change the default from `KWSSecure2026!` to something only you know
