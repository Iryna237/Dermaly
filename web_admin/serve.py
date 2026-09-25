"""Serveur de développement pour la console admin.

`python -m http.server` n'envoie aucun en-tête de cache, et les navigateurs
gardent alors les modules ES en cache disque : on modifie un fichier .js, on
recharge, et l'ancienne version s'affiche toujours. Ce serveur ajoute
`Cache-Control: no-store` à chaque réponse pour que ça n'arrive pas.

    python web_admin/serve.py [port]
"""

import functools
import http.server
import os
import sys


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5500
    root = os.path.dirname(os.path.abspath(__file__))
    handler = functools.partial(NoCacheHandler, directory=root)

    with http.server.ThreadingHTTPServer(('127.0.0.1', port), handler) as httpd:
        print(f'Console admin sur http://localhost:{port} (sans cache)')
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
