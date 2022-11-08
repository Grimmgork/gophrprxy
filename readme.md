# snappy, minimalistic, proxy to the gopherspace 🪐📂
*Written in Ruby ...*

![looks](https://github.com/Grimmgork/gophrprxy/blob/main/preview.png?raw=true)

Icons by https://win98icons.alexmeub.com/

## Setup:
Start the server:
```
ruby ./server.rb
```
Navigate like so:
```
http://localhost:5678/req/[GOPHERTYPE]/[HOST]:[PORT]/[PATH]
```
When gophertype is unknown, just omit the type segment or use a ```.```

Alternatively you can use the full-url interpreter:
```
http://localhost:5678/url?[encoded url]
```
Note that the url should ideally be fully url-encoded before passing it as a parameter!

There is a helper script for generating the full proxy url called ```open-url.rb```:
```
ruby open-url.rb localhost 1234 "http://gopher.floodgap.com/0/gopher"
outputs ->
http://localhost:1234/url?http%3A%2F%2Fgopher.floodgap.com%2F0%2Fgopher
redirects the browser to ->
http://localhost:1234/req/0/gopher.floodgap.com:70/gopher
```
this can be used to automate redirection of normal gopher:// urls to the proxy
