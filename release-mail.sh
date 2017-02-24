#!/bin/bash

# release-mail.sh - Release rspamd quarantined mail
# Copyright (c) 2017 [*] sys4 AG
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# -- Configuration -------------------------------------------------------------

# PostgreSQL configuration
DBHOST="127.0.0.1"
DBNAME="rspamd"
DBUSER="rspamd"

__version__='2017.02.1'
__author__="Christian Roessner <cr@sys4.de>"
__copyright__="Copyright (c) 2017 [*] sys4 AG"

# ------------------------------------------------------------------------------

if [[ "$#" -ne 2 ]]; then
    echo "$(basename $0) qid recipient"
    exit 1
fi

QID=$1
RCPT=$2

if [[ -z "${DBHOST}" ]]; then
    echo "No DBHOST var"
    exit 1
fi
if [[ -z "${DBNAME}" ]]; then
    echo "No DBNAME var"
    exit 1
fi
if [[ -z "${DBUSER}" ]]; then
    echo "No DBUSER var"
    exit 1
fi

psql="$(which psql 2>/dev/null)"
if [[ -z "${psql}" ]]; then
    echo "Command 'psql' not found"
    exit 1
fi
formail="$(formail 2>/dev/null)"
if [[ -z "${formail}" ]]; then
    echo "Command 'formail' not found"
    exit 1
fi

_psql="${psql} -At -h ${DBHOST} -d ${DBNAME} -U ${DBUSER}"

echo "SELECT content FROM msg WHERE qid='${QID}';" | $_psql | \
    ${formail} -s sendmail -oem -oi "$RCPT"

if [[ "$?" -eq 0 ]]; then
    echo "Message '${QID}' released and sent to ${RCPT}"
    echo "DELETE FROM msg WHERE qid='${QID}';" | $_psql -q
    echo "DELETE FROM meta WHERE qid='${QID}';" | $_psql -q
fi

exit 0
