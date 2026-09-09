#!/usr/bin/env python3
"""Placeholder API that demonstrates the Agrovesto runtime contract.

Replace with your real application. Keep:
  - bind 0.0.0.0 on PORT (default 8080)
  - GET /health returns 200 without auth
  - DB_* environment variables for SQL connectivity
"""
from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def db_status() -> dict:
    """Report whether the platform DB_* contract is present (no live SQL query here)."""
    required = ("DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD")
    present = {key: bool(os.environ.get(key)) for key in required}
    return {
        "configured": all(present.values()),
        "host": os.environ.get("DB_HOST"),
        "port": os.environ.get("DB_PORT"),
        "name": os.environ.get("DB_NAME"),
        "encrypt": os.environ.get("DB_ENCRYPT", "true"),
        "trust_server_certificate": os.environ.get("DB_TRUST_SERVER_CERTIFICATE", "false"),
        "fields_present": present,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "agrovesto-api-placeholder/1.0"

    def log_message(self, fmt: str, *args) -> None:  # quieter default logs
        sys_stderr = __import__("sys").stderr
        sys_stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _json(self, code: int, body: dict) -> None:
        payload = json.dumps(body).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path in {"/health", "/healthz", "/ready"}:
            # Readiness without auth — required by the ALB target group.
            self._json(200, {"status": "ok", "service": "api"})
            return
        if path == "/":
            self._json(
                200,
                {
                    "service": "agrovesto-api-placeholder",
                    "message": "Replace apps/api with your real API.",
                    "database": db_status(),
                },
            )
            return
        self._json(404, {"error": "not_found"})


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    # Must bind all interfaces so ALB / Docker port mapping can reach the process.
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"listening on 0.0.0.0:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
