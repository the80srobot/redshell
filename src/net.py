import http.server
import ssl
import socketserver
import base64

def serve(port:int=8443, directory:str="", certfile:str="", keyfile:str="", username:str="", password:str=""):
    class Handler(http.server.SimpleHTTPRequestHandler):
        def do_AUTHHEAD(self):
            self.send_response(401)
            self.send_header('WWW-Authenticate', 'Basic realm="Protected"')
            self.send_header('Content-type', 'text/html')
            self.end_headers()

        def do_GET(self):
            # Get the Authorization header
            auth_header = self.headers.get('Authorization')

            if not username or not password:
                super().do_GET()
            elif auth_header is None:
                self.do_AUTHHEAD()
                self.wfile.write(b"Unauthorized")
            else:
                # Extract credentials
                auth_type, encoded_creds = auth_header.split(' ')
                decoded_creds = base64.b64decode(encoded_creds).decode('utf-8')
                u, p = decoded_creds.split(':')

                # Verify username and password
                if u == username and p == password:
                    super().do_GET()
                else:
                    self.do_AUTHHEAD()
                    self.wfile.write(b"Unauthorized")

    httpd = socketserver.TCPServer(("0.0.0.0", port), Handler)
    if certfile and keyfile:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certfile=certfile, keyfile=keyfile)
        httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

    print(f"Serving HTTPS on port {port} from {directory}")
    httpd.serve_forever()
