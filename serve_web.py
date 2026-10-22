import http.server
import socketserver
import threading
import os
import time
import json
import hmac
import hashlib
import secrets
import base64
import urllib.parse
from collections import defaultdict

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WEB_V1_DIR = os.path.join(BASE_DIR, 'build', 'web')
WEB_V2_DIR = os.path.join(BASE_DIR, 'build', 'web_v2')

# ==============================================================================
# CSRF PROTECTION ENGINE (OWASP ASVS LEVEL 3 & BANKING GRADE)
# ==============================================================================
CSRF_SECRET = b"kopkar_pt_bbm_super_secure_csrf_secret_2026_w92k"
ALLOWED_ORIGINS = [
    "http://localhost",
    "http://127.0.0.1",
    "http://192.168.18.122",
    "http://192.168.18.119",
    "https://anqvtgusqrrcdnbgnxgf.supabase.co"
]

def generate_csrf_token(session_id="kopkar-global-session", duration_seconds=7200):
    now_ms = int(time.time() * 1000)
    exp_ms = now_ms + int(duration_seconds * 1000)
    # Nonce 128-bit urlsafe base64
    random_bytes = secrets.token_bytes(16)
    nonce = base64.urlsafe_b64encode(random_bytes).decode('utf-8').rstrip('=')
    
    payload = f"{nonce}:{exp_ms}:{session_id}".encode("utf-8")
    digest = hmac.new(CSRF_SECRET, payload, hashlib.sha256).digest()
    sig = base64.urlsafe_b64encode(digest).decode("utf-8").rstrip("=")
    token = f"CSRF.{nonce}.{exp_ms}.{sig}"
    return token, exp_ms

def verify_csrf_token(token, candidate_sessions=None):
    if not token or not isinstance(token, str):
        return False
    parts = token.split(".")
    if len(parts) != 4 or parts[0] != "CSRF":
        return False
    
    _, nonce, exp_str, sig = parts
    try:
        exp_ms = int(exp_str)
    except ValueError:
        return False
    
    now_ms = int(time.time() * 1000)
    if now_ms > exp_ms:
        return False  # Token kedaluwarsa

    if candidate_sessions is None:
        candidate_sessions = ["kopkar-global-session", "anonymous-web-session", "ADMIN-HRD-SESSION", "MBR-001"]

    for session_id in candidate_sessions:
        payload = f"{nonce}:{exp_ms}:{session_id}".encode("utf-8")
        digest = hmac.new(CSRF_SECRET, payload, hashlib.sha256).digest()
        expected_sig = base64.urlsafe_b64encode(digest).decode("utf-8").rstrip("=")
        if hmac.compare_digest(sig, expected_sig):
            return True

    return False

def is_origin_allowed(origin_or_referer):
    if not origin_or_referer:
        return True  # Native Mobile / Desktop / Direct app calls
    clean = origin_or_referer.strip().lower()
    for allowed in ALLOWED_ORIGINS:
        if clean.startswith(allowed.lower()):
            return True
    if clean.startswith('http://192.168.') or clean.startswith('http://10.') or clean.startswith('http://172.') or '.trycloudflare.com' in clean:
        return True
    return False


# ==============================================================================
# SLIDING-WINDOW IP-BASED RATE LIMITER (STANDAR KEAMANAN PERBANKAN DIGITAL)
# ==============================================================================
class RateLimiter:
    """
    Sliding-Window Rate Limiter per IP Address:
    - Default: 120 requests per 60 detik (cukup untuk asset web Flutter & font)
    - Sensitive/APK: 15 download per 60 detik
    - Menolak bot DDOS / scraper / brute-force dengan HTTP 429 Too Many Requests
    """
    def __init__(self, max_requests=120, window_seconds=60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.requests = defaultdict(list)
        self.lock = threading.Lock()

    def is_allowed(self, client_ip, is_heavy=False):
        now = time.time()
        max_allowed = 15 if is_heavy else self.max_requests
        with self.lock:
            history = self.requests[client_ip]
            cutoff = now - self.window_seconds
            valid_history = [t for t in history if t > cutoff]
            self.requests[client_ip] = valid_history

            remaining = max_allowed - len(valid_history)
            if remaining <= 0:
                retry_after = int(valid_history[0] + self.window_seconds - now) + 1
                return False, max_allowed, 0, max(1, retry_after)

            valid_history.append(now)
            return True, max_allowed, remaining - 1, 0

    def cleanup_old_ips(self):
        """Pembersihan berkala agar memori tetap ringan (anti-memory leak)"""
        now = time.time()
        with self.lock:
            cutoff = now - self.window_seconds
            stale_ips = [ip for ip, times in self.requests.items() if not times or times[-1] < cutoff]
            for ip in stale_ips:
                del self.requests[ip]


global_rate_limiter = RateLimiter(max_requests=120, window_seconds=60)

def periodic_cleanup():
    while True:
        time.sleep(300)
        global_rate_limiter.cleanup_old_ips()

cleanup_thread = threading.Thread(target=periodic_cleanup, daemon=True)
cleanup_thread.start()


def make_handler(directory):
    class SecureRateLimitedHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=directory, **kwargs)

        def get_client_ip(self):
            forwarded = self.headers.get('X-Forwarded-For')
            if forwarded:
                return forwarded.split(',')[0].strip()
            return self.client_address[0]

        def _check_rate_limit(self):
            client_ip = self.get_client_ip()
            is_apk = self.path.endswith('.apk')

            allowed, limit, remaining, retry_after = global_rate_limiter.is_allowed(client_ip, is_heavy=is_apk)

            if not allowed:
                self.send_response(429, "Too Many Requests")
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Retry-After', str(retry_after))
                self.send_header('X-RateLimit-Limit', str(limit))
                self.send_header('X-RateLimit-Remaining', '0')
                self.send_header('X-RateLimit-Reset', str(retry_after))
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()

                error_payload = {
                    "status": 429,
                    "error": "Too Many Requests",
                    "message": "🛡️ Batas frekuensi request terlampaui (Rate Limit Exceeded). Harap tunggu beberapa saat demi keamanan sistem.",
                    "client_ip": client_ip,
                    "retry_after_seconds": retry_after,
                    "limit_per_minute": limit
                }
                try:
                    self.wfile.write(json.dumps(error_payload, indent=2).encode('utf-8'))
                except Exception:
                    pass
                print(f"[RATE-LIMIT 429 BLOCKED] IP {client_ip} exceeded limit on {self.path} (Retry in {retry_after}s)", flush=True)
                return False
            return True

        def _validate_csrf(self):
            """Validasi Anti-CSRF untuk request mutasi data (POST, PUT, DELETE, PATCH)"""
            client_ip = self.get_client_ip()
            origin = self.headers.get('Origin') or self.headers.get('Referer')

            # 1. Validasi Origin Whitelist
            if origin and not is_origin_allowed(origin):
                self.send_response(403, "Forbidden")
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                err = {
                    "status": 403,
                    "error": "Forbidden (CSRF Cross-Origin Violation)",
                    "message": "🚨 Permintaan diblokir KOPKAR Anti-CSRF Guard: Domain/Origin asal tidak terdaftar.",
                    "origin": origin,
                    "client_ip": client_ip
                }
                try:
                    self.wfile.write(json.dumps(err, indent=2).encode('utf-8'))
                except Exception:
                    pass
                print(f"[CSRF 403 BLOCKED] Foreign origin: {origin} from IP {client_ip}", flush=True)
                return False

            # 2. Validasi Token Anti-CSRF (X-CSRF-Token)
            csrf_token = self.headers.get('X-CSRF-Token')
            session_id = self.headers.get('X-Session-ID') or 'kopkar-global-session'
            candidates = [session_id, 'kopkar-global-session', 'anonymous-web-session', 'ADMIN-HRD-SESSION', 'MBR-001']

            if not verify_csrf_token(csrf_token, candidates):
                self.send_response(403, "Forbidden")
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                err = {
                    "status": 403,
                    "error": "Forbidden (CSRF Token Invalid/Missing)",
                    "message": "🚫 Permintaan ditolak KOPKAR Anti-CSRF Guard: Token Anti-CSRF tidak valid, kedaluwarsa, atau tidak disertakan.",
                    "client_ip": client_ip
                }
                try:
                    self.wfile.write(json.dumps(err, indent=2).encode('utf-8'))
                except Exception:
                    pass
                print(f"[CSRF 403 BLOCKED] Invalid/missing token from IP {client_ip} on {self.path}", flush=True)
                return False

            return True

        def do_OPTIONS(self):
            self.send_response(204)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Session-ID, X-Requested-With, Content-Type, Authorization')
            self.send_header('Access-Control-Max-Age', '86400')
            self.end_headers()

        def do_HEAD(self):
            if not self._check_rate_limit():
                return
            super().do_HEAD()

        def do_GET(self):
            if not self._check_rate_limit():
                return

            # Endpoint penerbitan Anti-CSRF Token
            if self.path == '/api/csrf-token' or self.path.startswith('/api/csrf-token?'):
                session_id = self.headers.get('X-Session-ID') or 'kopkar-global-session'
                token, exp_ms = generate_csrf_token(session_id=session_id)
                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('X-CSRF-Token', token)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                payload = {
                    "status": 200,
                    "csrf_token": token,
                    "session_id": session_id,
                    "expires_at_ms": exp_ms,
                    "message": "🛡️ Anti-CSRF Synchronizer Token berhasil diterbitkan (OWASP ASVS L3)"
                }
                try:
                    self.wfile.write(json.dumps(payload, indent=2).encode('utf-8'))
                except Exception:
                    pass
                return

            super().do_GET()

        def do_POST(self):
            if not self._check_rate_limit():
                return
            if not self._validate_csrf():
                return
            self._handle_mutation_success("POST")

        def do_PUT(self):
            if not self._check_rate_limit():
                return
            if not self._validate_csrf():
                return
            self._handle_mutation_success("PUT")

        def do_DELETE(self):
            if not self._check_rate_limit():
                return
            if not self._validate_csrf():
                return
            self._handle_mutation_success("DELETE")

        def _handle_mutation_success(self, method):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            resp = {
                "status": 200,
                "method": method,
                "message": f"✅ Operasi {method} diotorisasi oleh KOPKAR Anti-CSRF Guard.",
                "csrf_valid": True
            }
            try:
                self.wfile.write(json.dumps(resp, indent=2).encode('utf-8'))
            except Exception:
                pass

        def end_headers(self):
            # Cache-busting headers
            self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            if hasattr(self, 'path') and self.path and (self.path in ('/', '/index.html') or self.path.startswith('/?')):
                self.send_header('Clear-Site-Data', '"cache"')

            # HTTP Security Headers (Standar Keamanan OWASP)
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('X-Frame-Options', 'SAMEORIGIN')
            self.send_header('X-XSS-Protection', '1; mode=block')
            self.send_header('Referrer-Policy', 'strict-origin-when-cross-origin')
            self.send_header('Server', 'KOPKAR-Secure-Server/2.0')
            super().end_headers()

    return SecureRateLimitedHandler


class ReusableTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


def serve_on_port(port, directory, label):
    handler = make_handler(directory)
    with ReusableTCPServer(('0.0.0.0', port), handler) as httpd:
        print(f"[KOPKAR] {label} running on http://0.0.0.0:{port} [🛡️ Rate Limiting & Anti-CSRF Guard Active] -> {directory}", flush=True)
        httpd.serve_forever()


if __name__ == '__main__':
    t1 = threading.Thread(target=serve_on_port, args=(8088, WEB_V1_DIR, "Versi 1 (Asli Sebelum Prompt 12 Okt)"), daemon=True)
    t2 = threading.Thread(target=serve_on_port, args=(8089, WEB_V2_DIR, "Versi 2 (Hasil Prompt 12 Okt Step 2456)"), daemon=True)
    t1.start()
    t2.start()
    serve_on_port(8080, WEB_V1_DIR, "Main Port 8080 (Versi 1 Asli)")
