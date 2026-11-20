"""Scans every file inside an APK for real secret keys.

FAIL  = a key that must never ship in an app (secret / service_role / private key).
INFO  = public-by-design values (Supabase publishable / anon key).
"""
import base64
import json
import re
import sys
import zipfile

FAIL_PATTERNS = {
    "Supabase secret key": rb"sb_secret_[A-Za-z0-9_\-]{10,}",
    "Razorpay LIVE key id (secret must stay on server)": rb"rzp_live_[A-Za-z0-9]{8,}",
    "Private key block": rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----",
    "AWS access key": rb"AKIA[0-9A-Z]{16}",
}
WARN_PATTERNS = {
    "Google API key": rb"AIza[0-9A-Za-z_\-]{35}",
}
JWT = re.compile(rb"eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}")
PUBLISHABLE = re.compile(rb"sb_publishable_[A-Za-z0-9_\-]{10,}")


def main(apk: str) -> int:
    failed = False
    seen_info = set()
    with zipfile.ZipFile(apk) as z:
        for name in z.namelist():
            data = z.read(name)
            for label, pat in FAIL_PATTERNS.items():
                for m in re.finditer(pat, data):
                    print(f"FAIL: {label} in {name}: {m.group(0)[:14].decode(errors='replace')}…")
                    failed = True
            for label, pat in WARN_PATTERNS.items():
                for m in re.finditer(pat, data):
                    print(f"WARN: {label} in {name} (make sure it is restricted to this app)")
            for m in JWT.finditer(data):
                try:
                    part = m.group(0).split(b".")[1]
                    part += b"=" * (-len(part) % 4)
                    role = json.loads(base64.urlsafe_b64decode(part)).get("role")
                except Exception:
                    continue
                if role == "service_role":
                    print(f"FAIL: service_role JWT (full database access) in {name}")
                    failed = True
                elif (name, role) not in seen_info:
                    seen_info.add((name, role))
                    print(f"INFO: JWT role={role} in {name} (anon key is public by design)")
            if PUBLISHABLE.search(data) and (name, "pub") not in seen_info:
                seen_info.add((name, "pub"))
                print(f"INFO: Supabase publishable key in {name} (public by design, protected by RLS)")
    print("OK: no secret keys inside the APK" if not failed else "FAIL: secret key(s) found")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
