worker_processes  auto;

error_log  /var/log/nginx/error.log;

events {
  worker_connections  1024;
}

http {
  server_tokens off;
  include       mime.types;
  default_type  application/octet-stream;

  client_max_body_size 64M;

  log_format  main  '$http_x_forwarded_for - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

  access_log  /var/log/nginx/access.log  main;

  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  
  gzip  on;
  gzip_http_version 1.1;
  gzip_vary on;
  gzip_comp_level 5;
  gzip_proxied any;
  gzip_types text/plain text/html text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript text/x-js;
  gzip_buffers 16 8k;
  gzip_disable "msie6";
  gzip_min_length 256;

  keepalive_timeout  8;
  
  # Upstream to abstract backend connection(s) for php
  upstream php {
    server 127.0.0.1:9000;
  }

  set_real_ip_from 10.0.0.0/8;
  real_ip_header X-Forwarded-For;
  real_ip_recursive on;
  
  # From http://wiki.nginx.org/Drupal
  
  server {
    server_name __DOMAIN;
    root /var/www/webroot/ROOT; ## <-- Your only path reference.

    # Enable compression, this will help if you have for instance advagg‎ module
    # by serving Gzip versions of the files.
    gzip_static on;

    location = /favicon.ico {
      log_not_found off;
      access_log off;
    }

    location = /robots.txt {
      allow all;
      log_not_found off;
      access_log off;
    }

    # This matters if you use drush prior to 5.x
    # After 5.x backups are stored outside the Drupal install.
    #location = /backup {
    #        deny all;
    #}

    # Very rarely should these ever be accessed outside of your lan
    location ~* \.(txt|log)$ {
      allow 192.168.0.0/16;
      deny all;
    }

    location ~ \..*/.*\.php$ {
      return 403;
    }

    # No no for private
    location ~ ^/sites/.*/private/ {
      return 403;
    }

    # Block access to "hidden" files and directories whose names begin with a
    # period. This includes directories used by version control systems such
    # as Subversion or Git to store control files.
    location ~ (^|/)\. {
      return 403;
    }

    location / {
      # This is cool because no php is touched for static content
      try_files $uri @rewrite;
    }

    location @rewrite {
      # You have 2 options here
      # For D7 and above:
      # Clean URLs are handled in drupal_environment_initialize().
      rewrite ^ /index.php;
      # For Drupal 6 and bwlow:
      # Some modules enforce no slash (/) at the end of the URL
      # Else this rewrite block wouldn't be needed (GlobalRedirect)
      #rewrite ^/(.*)$ /index.php?q=$1;
    }

    location ~ \.php$ {
      include fastcgi.conf;
      fastcgi_intercept_errors on;
      fastcgi_pass php;
    }

    # Fighting with Styles? This little gem is amazing.
    # This is for D6
    #location ~ ^/sites/.*/files/imagecache/ {
    # This is for D7 and D8
    location ~ ^/sites/.*/files/styles/ {
      try_files $uri @rewrite;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
      expires max;
      log_not_found off;
    }
  }
}
