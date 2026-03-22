# philiprehberger-task_runner

[![Tests](https://github.com/philiprehberger/rb-task-runner/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-task-runner/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-task_runner.svg)](https://rubygems.org/gems/philiprehberger-task_runner)
[![License](https://img.shields.io/github/license/philiprehberger/rb-task-runner)](LICENSE)

Shell command runner with output capture, timeout, and streaming.

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-task_runner"
```

Or install directly:

```bash
gem install philiprehberger-task_runner
```

## Usage

```ruby
require "philiprehberger/task_runner"

result = Philiprehberger::TaskRunner.run('ls', '-la')
puts result.stdout
puts result.exit_code    # => 0
puts result.success?     # => true
puts result.duration     # => 0.012
```

### Timeout

```ruby
result = Philiprehberger::TaskRunner.run('long-process', timeout: 30)
```

### Environment Variables and Working Directory

```ruby
result = Philiprehberger::TaskRunner.run(
  'make', 'build',
  env: { 'DEBUG' => '1' },
  chdir: '/path/to/project'
)
```

### Streaming Output

```ruby
Philiprehberger::TaskRunner.run('tail', '-f', '/var/log/app.log', timeout: 10) do |line|
  puts ">> #{line}"
end
```

## API

| Method / Class | Description |
|----------------|-------------|
| `.run(cmd, *args, timeout:, env:, chdir:)` | Run a command and return a Result |
| `.run(cmd) { \|line\| ... }` | Run with line-by-line stdout streaming |
| `Result#stdout` | Captured standard output |
| `Result#stderr` | Captured standard error |
| `Result#exit_code` | Process exit code |
| `Result#success?` | Whether exit code is 0 |
| `Result#duration` | Execution time in seconds |

## Development

```bash
bundle install
bundle exec rspec      # Run tests
bundle exec rubocop    # Check code style
```

## License

MIT
