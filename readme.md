# snappy, minimalistic, proxy to the gopherspace 🪐📂
*Written in Ruby ...*

![looks](https://github.com/Grimmgork/gophrprxy/blob/main/preview.png?raw=true)

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
or use the full-url interpreter:
```
http://localhost:5678/url?[encoded url]
```
Note that the url should ideally be fully url-encoded!
When type is unknown, just omit the type segment or use a dot .
