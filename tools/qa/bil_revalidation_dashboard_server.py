"""Serve only one local evidence directory, retaining its final result page."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--port', type=int, required=True)
    args = parser.parse_args()
    folder = args.directory.resolve(strict=True)

    class EvidenceHandler(SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(folder), **kw)

        def do_GET(self):
            if self.path.split('?', 1)[0] in ('/original-full-dashboard/', '/original-full-dashboard/index.html'):
                page = folder / 'original-full-dashboard/index.html'
                if page.is_file():
                    body = page.read_text(encoding='utf-8')
                    for name in ('state', 'github-state', 'current-work'):
                        body = body.replace(f"fetch('/{name}'", f"fetch('{name}'")
                    encoded = body.encode('utf-8')
                    self.send_response(200)
                    self.send_header('Content-Type', 'text/html; charset=utf-8')
                    self.send_header('Content-Length', str(len(encoded)))
                    self.send_header('Cache-Control', 'no-store')
                    self.end_headers()
                    self.wfile.write(encoded)
                    return
            super().do_GET()

        def end_headers(self):
            self.send_header('Cache-Control', 'no-store')
            super().end_headers()

    ThreadingHTTPServer(('127.0.0.1', args.port), EvidenceHandler).serve_forever()


if __name__ == '__main__':
    main()
