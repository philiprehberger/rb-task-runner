# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-04-09

### Added
- `TaskRunner.run!` raises `CommandError` on non-zero exit code (same API as `run`)
- `CommandError#result` exposes the full `Result` object for inspection
- `Result#to_h` for hash serialization of command results

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.0] - 2026-03-30

### Added

- Signal handling: `run(cmd, signal: :TERM, kill_after: 5)` sends the specified signal on timeout, escalates to SIGKILL after `kill_after` seconds
- `Result#signal` reports which signal killed the process (`:TERM`, `:KILL`, or `nil`)
- Input piping: `run(cmd, stdin: "data")` pipes string or IO data to the process's stdin
- Stderr streaming: two-argument blocks receive `(line, stream)` where stream is `:stdout` or `:stderr`
- Backward compatible: single-argument blocks still receive only stdout lines

## [0.1.4] - 2026-03-26

### Changed

- Add Sponsor badge and fix License link format in README

## [0.1.3] - 2026-03-24

### Fixed
- Fix README one-liner to remove trailing period

## [0.1.2] - 2026-03-24

### Fixed
- Remove inline comments from Development section to match template

## [0.1.1] - 2026-03-22

### Changed
- Expand test coverage

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Shell command execution with stdout and stderr capture
- Exit code and duration measurement on Result object
- Configurable timeout with TimeoutError
- Environment variable and working directory options
- Block-based streaming for line-by-line stdout processing
