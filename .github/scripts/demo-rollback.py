"""Demonstrate the Helios directory switch locally with a temporary HTTP server."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from subprocess import run
from shutil import which
from tempfile import TemporaryDirectory
from threading import Thread
from urllib.request import urlopen

script = Path(__file__).resolve().with_name("helios-release.sh")
shell = which("sh")
if not shell and which("git"):
    shell = str(Path(which("git")).resolve().parents[1] / "bin" / "sh.exe")
with TemporaryDirectory() as temp:
    root = Path(temp) / "public_html"
    handler = partial(SimpleHTTPRequestHandler, directory=str(root))
    with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
        Thread(target=server.serve_forever, daemon=True).start()

        def switch(action, version):
            run([shell or "sh", "-s", "--", action, "public_html/project", version],
                input=script.read_text().encode(), cwd=temp, check=True, capture_output=True)

        def verify(label, version):
            with urlopen(f"http://127.0.0.1:{server.server_port}/project/") as response:
                assert response.status == 200 and response.read().decode() == version
                print(label, response.status, version)

        for version in ("A", "B"):
            switch("prepare", version)
            (root / ".project-releases" / version / "index.html").write_text(version)
            if version == "B":
                verify("During upload", "A")
            switch("publish", version)
            verify("Publish", version)
        switch("rollback", "C")
        verify("Rollback", "A")
        server.shutdown()
