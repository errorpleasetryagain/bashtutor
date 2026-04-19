#!/usr/bin/env bash
# Mock Claude API server for testing
# Responds to API calls without needing a real API key

PORT=${1:-8888}

# Start a simple mock HTTP server that responds to /v1/messages
python3 -c "
import http.server
import json
from http import HTTPStatus

class MockAPIHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/v1/messages':
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)

            try:
                request_data = json.loads(body)
                user_message = request_data['messages'][0]['content']

                # Generate mock response based on request
                if 'bash command' in user_message.lower():
                    response_text = 'COMMAND: ls -la\nEXPLANATION: List files in long format'
                elif 'ls' in user_message.lower():
                    response_text = 'List files and directories in the current folder'
                else:
                    response_text = 'This command does something useful'

                response = {
                    'content': [{'text': response_text, 'type': 'text'}],
                    'model': 'claude-sonnet-4-20250514',
                    'stop_reason': 'end_turn'
                }

                self.send_response(HTTPStatus.OK)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
            except Exception as e:
                self.send_response(HTTPStatus.BAD_REQUEST)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': str(e)}).encode())
        else:
            self.send_response(HTTPStatus.NOT_FOUND)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress logging
        pass

server = http.server.HTTPServer(('localhost', $PORT), MockAPIHandler)
print('Mock API server started on port $PORT')
server.serve_forever()
" &

# Save the PID
echo $! > /tmp/mock_api.pid
sleep 1
