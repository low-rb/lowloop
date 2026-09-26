<a href="https://rubygems.org/gems/lowloop" title="Install gem"><img src="https://badge.fury.io/rb/lowloop.svg" alt="Gem version" height="18"></a>

# LowLoop

LowLoop is an asynchronous event-driven server that sents `RequestEvent`'s to [LowEvent](https://github.com/low-rb/lowevent). Finally you can see and track events through every step of your application, from the request layer right through to the application and data layers. Simply add `observe 'users/:id'` to a [LowNode](https://github.com/low-rb/lownode) and now it will be called every time a request is made to this route.

## Local Setup

Test things are working with:

```
bundle install
LOW_MIRROR=1 bin/start
```

The server will start a demo server in mirror mode, mirroring all of your requests as text in the response.
