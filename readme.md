# A minimalistic, personal gopher:// proxy 📂
Written in Ruby ...

Icons by https://win98icons.alexmeub.com/

## Setup:
start the server:
```
ruby ./server.rb
```
navigate like so:
```
http://localhost:5678/req/[GOPHERTYPE]/[HOST]:[PORT]/[PATH]
```
When type is unknown, just omit the type segment or use a dot .

## Default gopher:// app
to open a gopher://* url with the proxy automatically, use the open.rb script:
```
ruby ./open.rb gopher://gopher.floodgap.com
```
It will make the URL proxy-specific:
``` 
'http://localhost:5678/req/1/gopher.floodgap.com'
```

and opens it with the default http application.

You can register the ./open.rb script as the default app to open gopher://* urls in the windows registry :).