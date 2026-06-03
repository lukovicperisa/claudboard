"""
Renders the claudboard HTML mockups to PNG using headless Chrome.

For each screen (dashboard / run / gate), patches a temp copy of the
mockup so the React app starts on that screen, then screenshots it
via a local HTTP server (file:// breaks CDN scripts).
Analytics.html is screenshotted as-is.

Output → presentations/screenshots/*.png
"""

import http.server
import shutil
import socketserver
import subprocess
import threading
import time
from pathlib import Path

SRC = Path("/Users/LUP1BG/Documents/BoschProjects/bosch-workflow/Bosch workflow")
OUT = Path("/Users/LUP1BG/Documents/BoschProjects/claude-repo-scan/presentations/screenshots")
OUT.mkdir(parents=True, exist_ok=True)
STAGE = Path("/tmp/cb_stage")

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PORT = 8765

HIDE_TWEAKS_CSS = """
<style>
  .twk-panel, .twk-fab, [class*="twk-"] { display: none !important; }
</style>
"""

# (initial screen, html file used, output png)
SCREENS = [
    ("dashboard", "dashboard.html", "dashboard.png"),
    ("run",       "run.html",       "run.png"),
    ("gate",      "gate.html",      "gate.png"),
]


def stage_mockup():
    """Copy source mockup to a single staging dir and produce
    one HTML file per screen with the initial state baked in."""
    if STAGE.exists():
        shutil.rmtree(STAGE)
    shutil.copytree(SRC, STAGE)

    # Patch app.jsx — replace useState("run") with a window-controlled init
    app = STAGE / "src" / "app.jsx"
    text = app.read_text()
    text = text.replace(
        'const [screen, setScreen] = React.useState("run");',
        'const [screen, setScreen] = React.useState(window.__INIT_SCREEN__ || "run");',
    )
    app.write_text(text)

    # Base HTML
    base = (STAGE / "claudboard.html").read_text()
    # Inject hide-tweaks CSS once
    base = base.replace("</head>", HIDE_TWEAKS_CSS + "</head>")

    # Generate one HTML per screen with __INIT_SCREEN__ baked in
    for screen, html_name, _ in SCREENS:
        body = base.replace(
            "<body>",
            f'<body><script>window.__INIT_SCREEN__ = "{screen}";</script>',
        )
        (STAGE / html_name).write_text(body)


def start_server():
    """Start a quiet HTTP server in the staging dir."""
    class QuietHandler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a, **kw):
            pass

    handler = lambda *a, **kw: QuietHandler(*a, directory=str(STAGE), **kw)
    httpd = socketserver.TCPServer(("127.0.0.1", PORT), handler)
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    return httpd


def screenshot(url, out_path, width=1920, height=1200, wait_ms=6000):
    cmd = [
        CHROME,
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--hide-scrollbars",
        f"--window-size={width},{height}",
        f"--virtual-time-budget={wait_ms}",
        f"--screenshot={out_path}",
        url,
    ]
    print(f"  → {out_path.name}")
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        print("    STDERR:", r.stderr[-300:])


if __name__ == "__main__":
    print("Staging mockup...")
    stage_mockup()
    print(f"Starting HTTP server on :{PORT}...")
    httpd = start_server()
    time.sleep(0.5)

    print("Rendering screens...")
    try:
        for _, html_name, png_name in SCREENS:
            url = f"http://127.0.0.1:{PORT}/{html_name}"
            screenshot(url, OUT / png_name)
            time.sleep(0.3)
        # Analytics renders as-is (it's standalone, has its own scripts)
        screenshot(f"http://127.0.0.1:{PORT}/Analytics.html",
                   OUT / "analytics.png")
    finally:
        httpd.shutdown()

    print("\nFiles:")
    for f in sorted(OUT.glob("*.png")):
        size_kb = f.stat().st_size // 1024
        print(f"  {f.name}  ({size_kb} KB)")
