#!/usr/bin/env python3
"""
OpenConnect — serveur (à lancer sur TON PC)
Pas de ngrok, pas d'SSH — tout passe par Supabase HTTPS.
Usage : python3 server.py --secret TON_SECRET
"""
import argparse, hashlib, hmac, json, subprocess, sys, time, urllib.request, urllib.error

SUPABASE_URL = "https://vohddkxqdeivqcoogtzd.supabase.co"
ANON_KEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvaGRka3hxZGVpdnFjb29ndHpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2MjExNDMsImV4cCI6MjEwNDE5NzE0M30.nDc8h92CQi9x_US4FqzQN-mSL29VyRzsqKmNeLTVJLs"
POLL_INTERVAL = 1  # seconde

def sha256(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()

def secure_eq(a: str, b: str) -> bool:
    return hmac.compare_digest(a.encode(), b.encode())

def headers():
    return {
        "apikey":        ANON_KEY,
        "Authorization": f"Bearer {ANON_KEY}",
        "Content-Type":  "application/json",
        "Prefer":        "return=representation",
    }

def api(method: str, path: str, body=None):
    url  = f"{SUPABASE_URL}/rest/v1/{path}"
    data = json.dumps(body).encode() if body else None
    req  = urllib.request.Request(url, data=data, headers=headers(), method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read().decode()}")

def fetch_pending(secret_hash: str):
    path = f"osh_queue?status=eq.pending&secret_hash=eq.{secret_hash}&order=created_at.asc&limit=1"
    rows = api("GET", path)
    return rows[0] if rows else None

def update_row(row_id: str, stdout: str, stderr: str, returncode: int):
    api("PATCH", f"osh_queue?id=eq.{row_id}", {
        "status":     "done",
        "stdout":     stdout,
        "stderr":     stderr,
        "returncode": returncode,
        "updated_at": "now()",
    })

def run_cmd(cmd: str):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
        return r.stdout, r.stderr, r.returncode
    except subprocess.TimeoutExpired:
        return "", "timeout (60s)", -1
    except Exception as e:
        return "", str(e), -1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--secret", required=True)
    args = ap.parse_args()

    sh = sha256(args.secret)
    print()
    print("  OpenConnect — serveur (Supabase relay, sans ngrok)")
    print("  ════════════════════════════════════════════════════")
    print(f"  Relay : {SUPABASE_URL}")
    print(f"  Hash  : {sh[:16]}…")
    print()
    print("  En attente de commandes… (Ctrl+C pour arrêter)")
    print()

    while True:
        try:
            row = fetch_pending(sh)
            if row:
                cmd = row["cmd"]
                ts  = time.strftime("%H:%M:%S")
                print(f"  [{ts}] ► {cmd}")
                stdout, stderr, rc = run_cmd(cmd)
                update_row(row["id"], stdout, stderr, rc)
                print(f"  [{ts}] ✓ exit {rc}")
            else:
                time.sleep(POLL_INTERVAL)
        except KeyboardInterrupt:
            print("\n  Arrêt.")
            break
        except Exception as e:
            print(f"  ⚠ Erreur poll : {e}")
            time.sleep(3)

if __name__ == "__main__":
    main()
