Rspamd - quarantine service for the metadata_exporter module
------------------------------------------------------------

Rspamd offers a great LUA module called 'metadata_exporter' which can be used to send certain kind of data via email, HTTP-POST request or a custom defined function.

This project demonstrates an easy way to create a custom quarantine service using the HTTP-Post attempt.

Requirements
------------

A webserver like Nginx with a WSGI interface like uWSGI. If you want to store emails to SQL, you also must install a PostgreSQL server. For the script quarantine.py, you must install a Python 3 interpreter and psycopg.

Installation
------------

We describe both supported quarantine methods supported by this script, a file based store and SQL. For the file based system, you need to create a user called quarantine:

  useradd -r -m -d /var/quarantine -s /sbin/nologin -c "Rspamd quarantine" quarantine
  chmod 700 /var/quarantine

This will be the location, where the script stores file based emails and meta data.

If you want to remove older emails automatically, you can install a cron job like this:

As user root:

  crontab -e
  @daily find /var/quarantine -xdev -type f -mtime 30 -delete

For SQL, please create a database user and a database and adopt the permissions properly. For the release-mail-sh script, the user should also be able to connect to the database without providing a password on the same server. If you plan to run the database server outside localhost, create a psql config file and store the password there. We do not include PGPASSWORD in the script, as this variable was declared long ago.

Now install the SQL tables with the script quarantine.sql

For Nginx a setup could look like this:

  server {
      ... other config options ...
      location ~ /quarantine {
          include uwsgi_params;
          uwsgi_pass 127.0.0.1:9000;
      }
  ...
  }

This is a sample uwsgi config, as done under Gentoo Linux. Please adopt it for your distribution:

  UWSGI_SOCKET=127.0.0.1:9000
  UWSGI_THREADS=1
  UWSGI_PROCESSES=4
  UWSGI_LOG_FILE="/var/log/quarantine/uwsgi.log"
  UWSGI_PIDPATH_MODE=0750
  UWSGI_USER=quarantine
  UWSGI_GROUP=quarantine
  UWSGI_EMPEROR_PIDPATH_MODE=0770
  UWSGI_EXTRA_OPTIONS="--plugin python34 --python-path /usr/local/share/rspamd --module quarantine"

Create the following directories:

  mkdir -p /usr/local/share/rspamd
  mkdir -p /var/log/quarantine
  chown quarantine:quarantine /var/log/quarantine

Place the quarantine.py script in the /usr/local/share/rspamd folder. Logs go to the /var/log/quarantine/uwsgi.log file. Look for errors there. You can use the following logrotate script:

  /var/log/quarantine/uwsgi.log {
      compress
      delaycompress
      notifempty
      daily
      rotate 7
      create 0640 quarantine quarantine
      missingok
  }

If you edit the quarantine.py script, you will find a configuration block, where you can specify the SQL settings and file/sql usage. The block ist documented.

Change the permissions to this file that only the quarantine user can access it. It contains the psql password!

Now that the script is configured, you can start uWSGI and (re-)start Nginx.

metadata_exporter
-----------------

A sample configuration for this module might look like this:

  metadata_exporter {
      rules {
          META_HTTP_1 {
              backend = "http";
              url = "http://127.0.0.1/quarantine";
              selector = "is_reject";
              formatter = "default";
              meta_headers = true;
          }
      }
  }

See here for a full description of this module: https://rspamd.com/doc/modules/metadata_exporter.html

Have fun :)
