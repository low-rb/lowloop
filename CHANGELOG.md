# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Minor features that don't break backwards compatibility are released as patches.

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
