# philiprehberger-task_runner

[![Tests](https://github.com/philiprehberger/rb-task-runner/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-task-runner/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-task_runner.svg)](https://rubygems.org/gems/philiprehberger-task_runner)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-task-runner)](https://github.com/philiprehberger/rb-task-runner/commits/main)

Shell command runner with output capture, timeout, streaming, signal handling, and stdin piping

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

### Signal Handling

```ruby
result = Philiprehberger::TaskRunner.run(
  'long-process',
  timeout: 30,
  signal: :TERM,
  kill_after: 5
)
# On timeout: sends SIGTERM first, then SIGKILL after 5 seconds if still running
# result.signal reports which signal killed the process (:TERM, :KILL, or nil)
```

### Input Piping

```ruby
result = Philiprehberger::TaskRunner.run('cat', stdin: "hello world")
puts result.stdout  # => "hello world"

# Also accepts IO objects
result = Philiprehberger::TaskRunner.run('wc', '-l', stdin: File.open('data.txt'))
```

### Streaming Output

```ruby
Philiprehberger::TaskRunner.run('tail', '-f', '/var/log/app.log', timeout: 10) do |line|
  puts ">> #{line}"
end
```

### Stderr Streaming

```ruby
Philiprehberger::TaskRunner.run('make', 'build') do |line, stream|
  case stream
  when :stdout then puts "OUT: #{line}"
  when :stderr then puts "ERR: #{line}"
  end
end
```

## API

| Method / Class | Description |
|----------------|-------------|
| `.run(cmd, *args, timeout:, env:, chdir:, signal:, kill_after:, stdin:)` | Run a command and return a Result |
| `.run(cmd) { \|line\| ... }` | Run with line-by-line stdout streaming |
| `.run(cmd) { \|line, stream\| ... }` | Run with stdout and stderr streaming |
| `Result#stdout` | Captured standard output |
| `Result#stderr` | Captured standard error |
| `Result#exit_code` | Process exit code |
| `Result#success?` | Whether exit code is 0 |
| `Result#duration` | Execution time in seconds |
| `Result#signal` | Signal that killed the process (:TERM, :KILL, or nil) |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-task-runner)

🐛 [Report issues](https://github.com/philiprehberger/rb-task-runner/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-task-runner/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
