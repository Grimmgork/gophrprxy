# A Personal Gopher Proxy 📂
Written in Ruby ...

Icons by https://win98icons.alexmeub.com/

## Setup:
start the server:
```
ruby ./server.rb
```
You can now navigate like so:
```
http://localhost:5678/req/[gophertype]/[host]:[port]/[path]
```


## Default gopher: app
to open a gopher://* url with the proxy use the open.rb script:
```
ruby ./open.rb gopher://gopher.floodgap.com
```
It will transform the URL to 'http://localhost:5678/req/1/gopher.floodgap.com' and opens it with the default http browser.

You can register the ./open.rb script as the default app to open gopher://* urls.