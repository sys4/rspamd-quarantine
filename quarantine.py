"""
quarantine - Rspamd quarantine support
Copyright (c) 2017 [*] sys4 AG

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

import os
import sys
import traceback
import gzip
import json

from wsgiref.simple_server import make_server
from html import escape

# -- Configuration -------------------------------------------------------------

# PostgreSQL configuration
DBCONF = {
    'host': "127.0.0.1",
    'dbname': "rspamd",
    'user': "rspamd",
    'password': "password_here"
}
USE_SQL = True

PREFIX = "/var/quarantine"
USE_FILE = True

# Store mails only on selected symbols. Set to None to disable
# Example: ONLY_SYMBOLS = ['CLAMAV_VIRUS', 'AVIRA_VIRUS']
ONLY_SYMBOLS = None


__version__ = '2017.02.1'
__author__ = "Christian Roessner <cr@sys4.de>"
__copyright__ = "Copyright (c) 2017 [*] sys4 AG"

# ------------------------------------------------------------------------------

if USE_SQL:
    import psycopg2


# noinspection SqlNoDataSourceInspection
def application(environ, start_response):
    # HTTP status codes
    stat_ok = "200 OK"
    stat_err = "500 Internal Server Error"

    response_body = b""

    status = stat_ok

    request_method = environ['REQUEST_METHOD']
    request_method = escape(request_method)

    if request_method == "POST":
        try:
            request_body_size = int(environ.get('CONTENT_LENGTH', 0))
        except ValueError as v:
            print("Error for CONTENT LENGTH:", v, file=sys.stderr)
            request_body_size = 0

        request_body = environ['wsgi.input'].read(request_body_size)

        if "HTTP_X_RSPAMD_QID" in environ:
            qid = environ["HTTP_X_RSPAMD_QID"]
        else:
            qid = None

        symbol_matches = True
        if isinstance(ONLY_SYMBOLS, list):
            if "HTTP_X_RSPAMD_SYMBOLS" in environ:
                syms = json.loads(environ['HTTP_X_RSPAMD_SYMBOLS'])
                for rule in iter(syms):
                    if rule['name'] in ONLY_SYMBOLS:
                        symbol_matches = True
                        break
                else:
                    symbol_matches = False

        if qid and symbol_matches:
            if USE_SQL:
                conn = psycopg2.connect("host=%(host)s "
                                        "dbname=%(dbname)s "
                                        "user=%(user)s "
                                        "password=%(password)s" % DBCONF)
                cur = conn.cursor()

                meta = {
                    'qid': None,
                    'score': 0.0,
                    'ip': None,
                    'action': "",
                    'from': b"",
                    'symbols': None
                }
            else:
                cur = None
                conn = None

            if USE_FILE:
                try:
                    with gzip.open("{0}/{1}-meta.gz".format(PREFIX, qid),
                                   "wb") as f:
                        for k, v in environ.items():
                            if k.startswith("HTTP_X_RSPAMD"):
                                k = k[14:]
                                f.write(bytes(
                                    "%s: %s\n" % (k, v), encoding="utf-8"))
                except Exception as e:
                    print("Error while trying to write file "
                          "{0}-meta: {1}".format(qid, e), file=sys.stderr)
                    status = stat_err

            if USE_SQL and conn:
                for k, v in environ.items():
                    if k.startswith("HTTP_X_RSPAMD"):
                        k = k[14:]
                        if k == "QID":
                            meta['qid'] = v
                        elif k == "SCORE":
                            meta['score'] = v
                        elif k == "IP":
                            meta['ip'] = v
                        elif k == "ACTION":
                            meta['action'] = v
                        elif k == "FROM":
                            meta['from'] = v
                        elif k == "SYMBOLS":
                            meta['symbols'] = v
                try:
                    if meta['qid']:
                        cur.execute("""
                            INSERT INTO meta 
                            (qid, timestamp, score, ip, action, "from", symbols)
                            VALUES 
                            (%s, NOW(), %s, %s, %s, %s, %s)""", (
                                    meta['qid'],
                                    meta['score'],
                                    meta['ip'],
                                    meta['action'],
                                    meta['from'],
                                    meta['symbols']))
                        conn.commit()
                except Exception as e:
                    print("Error while trying to write SQL: {0}".format(e),
                          file=sys.stderr)
                    status = stat_err

            if USE_FILE:
                try:
                    with gzip.open("{0}/{1}-msg.gz".format(PREFIX, qid),
                                   "wb") as fd:
                        fd.write(request_body)
                except Exception as e:
                    print("Error while trying to write file "
                          "{0}-msg: {1}".format(qid, e), file=sys.stderr)
                    status = stat_err

            if USE_SQL and conn:
                try:
                    if meta['qid']:
                        cur.execute("""
                            INSERT INTO msg
                            (qid, content) 
                            VALUES
                            (%s, %s)""", (
                                meta['qid'], 
                                str(request_body, encoding="utf-8")))
                        conn.commit()
                        cur.close()
                        conn.close()
                except Exception as e:
                    print("Error while trying to write SQL: {0}".format(e),
                          file=sys.stderr)
                    status = stat_err

            response_body = b"qid=" + bytes(qid, encoding="utf-8")

        else:
            response_body = b"quarantine_file=<none>"

    body_len = str(len(response_body))

    response_headers = [('Content-Type', 'text/plain'),
                        ('Content-Length', body_len)]

    start_response(status, response_headers)

    return [response_body]

if __name__ == "__main__":
    httpd = make_server('localhost', 8080, application)
    httpd.handle_request()

# vim: expandtab ts=4 sw=4
