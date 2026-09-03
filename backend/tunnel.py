"""
Helper script to expose the local WalkieTalkie FastAPI backend to the public internet using Cloudflare Tunnel.
Cloudflare provides free, unlimited, low-latency HTTPS and WSS connections worldwide without sign-up.
"""

import subprocess
import sys
import os
import re

PORT = 8000
CLOUDFLARED_PATH = os.path.join(os.path.dirname(__file__), "cloudflared.exe")

def run_tunnel():
    print("=" * 65)
    print(f"  Starting High-Speed Internet Tunnel for SSTA-WalkieTalkie (Port {PORT})")
    print("=" * 65)

    if os.path.exists(CLOUDFLARED_PATH):
        print("Starting Cloudflare Tunnel...")
        cmd = [CLOUDFLARED_PATH, "tunnel", "--url", f"http://localhost:{PORT}"]
    else:
        print("Using fallback localtunnel...")
        cmd = ["npx", "localtunnel", "--port", str(PORT)]

    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )

        for line in iter(proc.stdout.readline, ''):
            # Cloudflare tunnel prints: https://xxxx.trycloudflare.com
            match = re.search(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", line)
            if not match and "your url is:" in line.lower():
                match = re.search(r"https://[^\s]+", line)

            if match:
                tunnel_url = match.group(0).strip()
                print("\n" + "#" * 65)
                print(f"  PUBLIC TUNNEL URL: {tunnel_url}")
                print("#" * 65)
                print("\nHOW TO CONNECT FROM YOUR PHONE:")
                print(f"1. Open Walkie Talkie on your phone.")
                print(f"2. Tap 'Change Server IP' or the '<->' icon.")
                print(f"3. Paste the URL above:")
                print(f"   {tunnel_url}")
                print(f"4. Tap 'Connect'.")
                print("\nCloudflare provides encrypted HTTPS & real-time WebSocket audio streaming!")
                print("-" * 65)
            else:
                if "INF" not in line and "ERR" not in line:
                    sys.stdout.write(line)
                    sys.stdout.flush()

        proc.wait()
    except KeyboardInterrupt:
        print("\nTunnel stopped.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    run_tunnel()
