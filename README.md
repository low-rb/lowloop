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

## Intervals

Observe an `Interval` to run code periodically. LowLoop triggers each observed interval with the `tick` action when it's due:

```ruby
class Cleanup < LowNode
  observe Interval[every_minute: 3, at_hour: 2] # Every 3 minutes during 2am.

  def tick
    # ...
  end
end
```

An interval counts in `every_second`, `every_minute`, `every_hour` or `every_day`, and `at_hour:` keeps it to that hour of the day. Its turns follow the server's clock, so `every_minute: 10` runs at :00, :10, :20 and so on. It waits for its first turn after the app starts, so restarting doesn't make it run early. The same schedule observed in two places is one interval, so both are ticked together.

Intervals run one at a time on a thread of their own, so a slow job never holds up requests, and one that runs longer than its interval skips the turns it missed. What a job shares with requests needs to be safe across threads, like a `Thread::Queue`.
