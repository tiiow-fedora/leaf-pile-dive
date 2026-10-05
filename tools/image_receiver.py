"""Tiny localhost receiver: the Gemini/ChatGPT tab POSTs a generated image here
(fetch → blob → POST /save?name=...) and it is written to assets/thumbnails/ai/raw/.
Listens on 127.0.0.1 only. Handles the CORS + Private Network Access preflight."""
import http.server, pathlib, re, urllib.parse

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "thumbnails" / "ai" / "raw"
OUT.mkdir(parents=True, exist_ok=True)

class H(http.server.BaseHTTPRequestHandler):
    def cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Private-Network", "true")

    def do_OPTIONS(self):
        self.send_response(204); self.cors(); self.end_headers()

    def do_POST(self):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        name = re.sub(r"[^A-Za-z0-9_.-]", "_", q.get("name", ["image.png"])[0])
        data = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        (OUT / name).write_bytes(data)
        self.send_response(200); self.cors(); self.end_headers()
        self.wfile.write(f"saved {name} {len(data)}".encode())
        print("saved", name, len(data), flush=True)

http.server.HTTPServer(("127.0.0.1", 8765), H).serve_forever()
