# TODO

- LowEvent's event pool is a plain hash shared by requests and interval jobs. It hasn't caused problems, but it isn't strictly thread-safe. If interval jobs start triggering many events, that's the place to add a lock.
