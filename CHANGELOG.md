# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Minor features that don't break backwards compatibility are released as patches.

## Unreleased

### Changed

- Responses use less memory. A buffered body is written as its chunks rather than joined into a copy first, and the response is built in one string sized to fit, still sent in a single write. Headers and a body in different encodings no longer raise an encoding error

## 0.8.9

### Added

- `Interval`, a schedule to observe to run code periodically, like `observe Interval[every_minute: 3, at_hour: 2]`. LowLoop triggers each observed interval with the `tick` action when it's due, one at a time on a thread of its own, so a slow job never holds up requests, and one that runs longer than its interval skips the turns it missed

## 0.8.8

### Fixed

- Responses no longer send a `Host` header, which only requests have, naming the address the server listens on, like `Host: 127.0.0.1:4133`

## 0.8.7

### Fixed

- A header with an empty value, like `Accept-Language:`, or none after its colon closed the connection without a response
- A request repeating a header there can only be one of, like two Referers, closed the connection without a response, and now gets 400 Bad Request
- Output is written as it happens, so a log like journald's shows when each error was rather than when the server stopped

## 0.8.6

### Added

- Files are sent with when they last changed, and a browser whose copy is current is answered 304 Not Modified
- The app decides how its files are cached with `cache_control` in its config, one for every file, like `no-cache`, or one for each extension, sending none without it

## 0.8.4

### Fixed

- Requests with a body closed the connection instead of being parsed
- Responses without a body closed the connection instead of being sent
- Errors closed the connection instead of responding with a 500
- Waiting for ENTER after an error stopped the server responding, now only the matrix is paused

## 0.8.0

### Changed

- Rename "handle" action to "request" for both routes and files

## 0.7.0

### Fixed

- Fix corrupted headers on every HTTP response
- Strip response body of line breaks

## 0.6.0

### Added

- Introduce debug mode
- Block fiber and show backtrace on error in debug mode

### Fixed

- Fixed mirror mode

## 0.5.0

### Added

- Add background task loop

### Changes

- Render frames at 10fps
- Provide current screen size on each render
- Leave screen clearing up to renderer

## 0.4.0

### Added

- Introduce low frame
- Support external renderers

## 0.3.0

### Added

- Introduce file server

## 0.2.0

### Added

- Take request events from observers of low loop instance

## 0.1.0

### Added

- Mirror mode
