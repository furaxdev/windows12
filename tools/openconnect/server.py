#!/usr/bin/env python3
"""
OpenConnect — serveur de commandes HTTPS (à lancer sur TON PC)
Écoute en local, exposé publiquement via ngrok.
Usage : python3 server.py --secret TON_SECRET_ICI [--port 7800]
"""
import argparse, hashlib, hmac, json, os, subprocess, sys, time
from http.server import BaseHTTPRequestHandler, HTTPServer

def sha256(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()

def secure_compare(a: str, b: str) -> bool:
    return hmac.compare_digest(a.encode(), b.encode())

SECRET_HASH = ""

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        ts = time.strftime("%H:%M:%S")
        print(f"  [{ts}] {fmt % args}")

    def send_json(self, code: int, data: dict):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path != "/run":
            self.send_json(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length", 0))
        try:
            body = json.loads(self.rfile.read(length))
        except Exception:
            self.send_json(400, {"error": "invalid json"})
            return

        secret = body.get("secret", "")
        cmd    = body.get("cmd", "")

        if not secure_compare(sha256(secret), SECRET_HASH):
            self.send_json(403, {"error": "wrong secret"})
            return

        if not cmd:
            self.send_json(400, {"error": "cmd manquant"})
            return

        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=60
            )
            self.send_json(200, {
                "stdout":      result.stdout,
                "stderr":      result.stderr,
                "returncode":  result.returncode,
            })
        except subprocess.TimeoutExpired:
            self.send_json(200, {"stdout": "", "stderr": "timeout (60s)", "returncode": -1})
        except Exception as e:
            self.send_json(500, {"error": str(e)})

    def do_GET(self):
        if self.path == "/ping":
            self.send_json(200, {"status": "ok"})
        else:
            self.send_json(404, {"error": "not found"})

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--secret", required=True, help="Secret partagé (choisis-en un long)")
    ap.add_argument("--port", type=int, default=7800)
    args = ap.parse_args()

    global SECRET_HASH
    SECRET_HASH = sha256(args.secret)

    print()
    print("  OpenConnect — serveur de commandes")
    print("  ════════════════════════════════════")
    print(f"  Port local : {args.port}")
    print(f"  Secret hash : {SECRET_HASH[:16]}…  (ne partage pas le secret, seulement l'URL ngrok)")
    print()
    print("  Lance ngrok dans un autre terminal :")
    print(f"    ngrok http {args.port}")
    print()
    print("  Ctrl+C pour arrêter.")
    print()

    server = HTTPServer(("127.0.0.1", args.port), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n  Arrêt.")

if __name__ == "__main__":
    main()
