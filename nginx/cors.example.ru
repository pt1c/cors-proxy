map $request_uri $proxy_uri {
  ~*/http://(.*)/(.+)$  "http://$1/$2";
  ~*/https://(.*)/(.+)$ "https://$1/$2";
  ~*/http://(.*)$       "http://$1/";
  ~*/https://(.*)$      "https://$1/";
  ~*/(.*)/(.+)$         "https://$1/$2";
  ~*/(.*)$              "https://$1/";
  default               "";
}

map $proxy_uri $proxy_origin {
  ~*(.*)/.*$ $1;
  default    "";
}

map $remote_addr $proxy_forwarded_addr {
  ~^[0-9.]+$        "for=$remote_addr";
  ~^[0-9A-Fa-f:.]+$ "for=\"[$remote_addr]\"";
  default           "for=unknown";
}

map $http_forwarded $proxy_add_forwarded {
  ""      "$proxy_forwarded_addr";
  default "$http_forwarded, $proxy_forwarded_addr";
}

server {
  listen 443 ssl;
  
  ssl_certificate /etc/letsencrypt/live/cors.example.ru/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/cors.example.ru/privkey.pem;
  ssl_trusted_certificate /etc/letsencrypt/live/cors.example.com/chain.pem;
  
  server_name cors.example.ru;
  
  sendfile                   on;
  tcp_nodelay                on;
  tcp_nopush                 on;
  
  etag                       off;
  if_modified_since          off;
  
  proxy_buffering            off;
  proxy_cache                off;
  proxy_cache_convert_head   off;
  proxy_max_temp_file_size   0;
  client_max_body_size       0;
  
  proxy_http_version         1.1;
  proxy_pass_request_headers on;
  proxy_pass_request_body    on;
  
  proxy_read_timeout         1m;
  proxy_connect_timeout      1m;
  reset_timedout_connection  on;
  
  proxy_redirect             off;
  resolver                   77.88.8.8 77.88.8.1 8.8.8.8 8.8.4.4 valid=1d;
  
  gzip                       off;
  gzip_proxied               off;
  # brotli                   off;
  
  location / {
    if ($proxy_uri = "") {
      return 403;
    }
    
    # add proxy cors
    add_header 'Access-Control-Allow-Origin' "$http_origin" always;
    add_header 'Access-Control-Allow-Headers' "$http_access_control_request_headers" always;
    add_header 'Access-Control-Request-Method' "$http_access_control_request_method" always;

    if ($request_method = "OPTIONS") {
      return 204;
    }
    
    # pass client to proxy
    proxy_set_header Host                $proxy_host;
    proxy_set_header Origin              $proxy_origin;
    proxy_set_header X-Real-IP           $remote_addr;
    proxy_set_header X-Client-IP         $remote_addr;
    proxy_set_header CF-Connecting-IP    $remote_addr;
    proxy_set_header Fastly-Client-IP    $remote_addr;
    proxy_set_header True-Client-IP      $remote_addr;
    proxy_set_header X-Cluster-Client-IP $remote_addr;
    proxy_set_header X-Forwarded-For     $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto   $scheme;
    proxy_set_header Forwarded           "$proxy_add_forwarded;proto=$scheme";
    
    # hide original cors
    proxy_hide_header Access-Control-Allow-Credentials;
    proxy_hide_header Access-Control-Allow-Headers;
    proxy_hide_header Access-Control-Allow-Methods;
    proxy_hide_header Access-Control-Allow-Origin;
    proxy_hide_header Access-Control-Expose-Headers;
    proxy_hide_header Access-Control-Max-Age;
    proxy_hide_header Access-Control-Request-Headers;
    proxy_hide_header Access-Control-Request-Method;
    
    proxy_pass $proxy_uri;
  }
}