#!/bin/sh
set -e

# Check if PHP-FPM is responding
SCRIPT_NAME=/health SCRIPT_FILENAME=/health REQUEST_METHOD=GET \
cgi-fcgi -bind -connect 127.0.0.1:9001 || exit 1

exit 0
