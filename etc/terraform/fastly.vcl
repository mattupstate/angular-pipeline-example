sub vcl_recv {
  if (req.url == "/") {
    error 900 "Root URL";
  }

  if(req.url ~ "^/(en-US|es-US)") {
    set req.http.X-Current-Language = re.group.1;

    if (req.http.host ~ "^([a-zA-Z0-9]{7})\.angular\-pipeline\-example\.mattupstate\.com$") {
      set req.http.X-Key-Prefix = "/" re.group.1;
    } else {
      set req.http.X-Key-Prefix = "/_latest";
    }

    if (req.url ~ "\.(js|map|css|txt|html|ico|png|gif|jpg)$") {
      set req.url = req.http.X-Key-Prefix req.url;
    } else {
      set req.url = req.http.X-Key-Prefix  "/" req.http.X-Current-Language "/index.html";
    }
  }

#FASTLY recv

  if (req.method != "HEAD" && req.method != "GET" && req.method != "FASTLYPURGE") {
    return(pass);
  }

  return(lookup);
}

sub vcl_fetch {
  if (beresp.status == 301 || beresp.status == 302) {
    if (beresp.http.Location ~ "^/_latest/") {
      set beresp.http.Location = regsub(beresp.http.Location, "^/_latest/", "/");
    }
    if (beresp.http.Location ~ "^/([a-zA-Z0-9]{7})/") {
      set beresp.http.Location = regsub(beresp.http.Location, "^/([a-zA-Z0-9]{7})/", "/");
    }
  }

  unset beresp.http.x-amz-id-2;
  unset beresp.http.x-amz-request-id;
  unset beresp.http.server;

#FASTLY fetch

  if ((beresp.status == 500 || beresp.status == 503) && req.restarts < 1 && (req.method == "GET" || req.method == "HEAD")) {
    restart;
  }

  if (req.restarts > 0) {
    set beresp.http.Fastly-Restarts = req.restarts;
  }

  if (beresp.http.Set-Cookie) {
    set req.http.Fastly-Cachetype = "SETCOOKIE";
    return(pass);
  }

  if (beresp.http.Cache-Control ~ "private") {
    set req.http.Fastly-Cachetype = "PRIVATE";
    return(pass);
  }

  if (beresp.status == 500 || beresp.status == 503) {
    set req.http.Fastly-Cachetype = "ERROR";
    set beresp.ttl = 1s;
    set beresp.grace = 5s;
    return(deliver);
  }

  if (beresp.http.Expires || beresp.http.Surrogate-Control ~ "max-age" || beresp.http.Cache-Control ~ "(s-maxage|max-age)") {
    # keep the ttl here
  } else {
    # apply the default ttl
    set beresp.ttl = 3600s;
  }

  return(deliver);
}

sub vcl_hit {
#FASTLY hit

  if (!obj.cacheable) {
    return(pass);
  }
  return(deliver);
}

sub vcl_miss {
#FASTLY miss
  return(fetch);
}

sub vcl_deliver {
  if (resp.status == 900 ) {
    set resp.status = 301;
    set resp.response = "Moved Permanently";
  }

  if( req.url == "/" && resp.status == 301 ) {
    set resp.http.Location = "/" accept.language_lookup("en-US:es-US", "en-US", req.http.Accept-Language);
  }

#FASTLY deliver
  return(deliver);
}

sub vcl_error {
  if (obj.status == 3011 ) {
    return(deliver);
  }
#FASTLY error
}

sub vcl_pass {
#FASTLY pass
}

sub vcl_log {
#FASTLY log
}
