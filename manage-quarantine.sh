#!/bin/bash

# manage-quarantine.sh - Release rspamd quarantined mail
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

__version__='2017.03.1'
__author__="Christian Roessner <cr@sys4.de>"
__copyright__="Copyright (c) 2017 [*] sys4 AG"

# ------------------------------------------------------------------------------

function usage() {
    cat << EOD
$(basename $0) command [ queue-id ] [ recipient ]"

    command:

    list            - Get a full list of all queue ids and the Envelope-From
    release         - Release an email from quarantine and send it to a recipient
    delete          - Delete an email from quarantine
    print           - Print out the content of an email
    meta            - Print meta data for an email
EOD
}

function need_snd_arg() {
    if [[ -z "${QID}" ]]; then
        usage
        exit 1
    fi
}

if [[ -z "$1" ]]; then
    usage
    exit 1
fi

CMD=$1
QID=$2
RCPT=$3

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
formail="$(which formail 2>/dev/null)"
if [[ -z "${formail}" ]]; then
    echo "Command 'formail' not found"
    exit 1
fi
xxd="$(which xxd 2>/dev/null)"
if [[ -z "${xxd}" ]]; then
    echo "Command 'xxd' not found"
    exit 1
fi

_psql="${psql} -At -h ${DBHOST} -d ${DBNAME} -U ${DBUSER}"
_xxd="${xxd} -r -p"

case "${CMD}" in
    list)
        echo "SELECT qid, \"from\" FROM meta;" | $_psql | \
        while read qid from; do
            echo -ne "${qid}\t\t"
            echo "${from}" | $_xxd
            echo
        done
        ;;
    release)
        need_snd_arg

        if [[ -z "${RCPT}" ]]; then
            usage
            exit 1
        fi

        echo "SELECT content FROM msg WHERE qid='${QID}';" | $_psql | \
            ${formail} -s sendmail -oem -oi "${RCPT}"

        if [[ "$?" -eq 0 ]]; then
            echo "Message '${QID}' released and sent to ${RCPT}"
            echo "DELETE FROM msg WHERE qid='${QID}';" | $_psql -q
            echo "DELETE FROM meta WHERE qid='${QID}';" | $_psql -q
        fi
        ;;
    print)
        need_snd_arg

        echo "SELECT content FROM msg WHERE qid='${QID}';" | $_psql
        ;;
    delete)
        need_snd_arg

        echo "Do you really want to delete message with queue ID '${QID} (y/N)'?"
        read answer

        if [[ "${answer}" == "y" || "${answer}" == "Y" ]]; then
            echo "DELETE FROM msg WHERE qid='${QID}';" | $_psql -q
            echo "DELETE FROM meta WHERE qid='${QID}';" | $_psql -q
            echo "Message '${QID}' deleted"
        else
            echo "Message '${QID}' was _not_ deleted"
        fi
        ;;
    meta)
        need_snd_arg

        declare -i result
        result=$(echo "SELECT count(*) FROM meta WHERE qid='${QID}';" | $_psql)

        if [[ "${result}" -ne 0 ]]; then
            echo "Timestamp:"
            echo "SELECT timestamp FROM meta WHERE qid='${QID}';" | $_psql
            echo

            echo "Score:"
            echo "SELECT score FROM meta WHERE qid='${QID}';" | $_psql
            echo

            echo "IP:"
            echo "SELECT ip FROM meta WHERE qid='${QID}';" | $_psql
            echo

            echo "Action:"
            echo "SELECT action FROM meta WHERE qid='${QID}';" | $_psql
            echo

            echo "Envelope-From:"
            echo "SELECT \"from\" FROM meta WHERE qid='${QID}';" | $_psql | $_xxd
            echo
            echo

            echo "Symbols:"
            echo "SELECT symbols FROM meta WHERE qid='${QID}';" | $_psql
            echo
        fi
        ;;
    *)
        usage
        ;;
esac

exit 0

# vim: ts=4 sw=4 expandtab
