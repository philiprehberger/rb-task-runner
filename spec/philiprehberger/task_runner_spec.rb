# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Philiprehberger::TaskRunner do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::TaskRunner::VERSION).not_to be_nil
    end

    it 'is a non-empty string' do
      expect(Philiprehberger::TaskRunner::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe '.run' do
    it 'captures stdout' do
      result = described_class.run('echo', 'hello')
      expect(result.stdout.strip).to eq('hello')
    end

    it 'captures stderr' do
      result = described_class.run('ruby', '-e', '$stderr.puts "oops"')
      expect(result.stderr.strip).to eq('oops')
    end

    it 'returns exit code 0 for successful commands' do
      result = described_class.run('true')
      expect(result.exit_code).to eq(0)
      expect(result.success?).to be true
    end

    it 'returns non-zero exit code for failed commands' do
      result = described_class.run('false')
      expect(result.exit_code).not_to eq(0)
      expect(result.success?).to be false
    end

    it 'measures duration' do
      result = described_class.run('true')
      expect(result.duration).to be_a(Float)
      expect(result.duration).to be >= 0
    end

    it 'accepts environment variables' do
      result = described_class.run('ruby', '-e', 'puts ENV["MY_VAR"]', env: { 'MY_VAR' => 'test_value' })
      expect(result.stdout.strip).to eq('test_value')
    end

    it 'accepts a working directory' do
      result = described_class.run('pwd', chdir: '/')
      expect(result.stdout.strip).to match(%r{^/})
    end

    it 'raises TimeoutError when command exceeds timeout' do
      expect do
        described_class.run('sleep', '10', timeout: 0.2)
      end.to raise_error(Philiprehberger::TaskRunner::TimeoutError)
    end

    it 'captures multi-line stdout' do
      result = described_class.run('ruby', '-e', '3.times { |i| puts i }')
      lines = result.stdout.strip.split("\n")
      expect(lines).to eq(%w[0 1 2])
    end

    it 'captures both stdout and stderr simultaneously' do
      result = described_class.run('ruby', '-e', 'puts "out"; $stderr.puts "err"')
      expect(result.stdout.strip).to eq('out')
      expect(result.stderr.strip).to eq('err')
    end

    it 'returns empty stdout for commands with no output' do
      result = described_class.run('true')
      expect(result.stdout).to eq('')
    end

    it 'returns empty stderr for commands with no error output' do
      result = described_class.run('echo', 'hello')
      expect(result.stderr).to eq('')
    end

    it 'handles commands with special characters in arguments' do
      result = described_class.run('echo', 'hello world')
      expect(result.stdout.strip).to match(/hello world/)
    end

    it 'passes multiple env variables' do
      result = described_class.run(
        'ruby', '-e', 'puts ENV["A"]; puts ENV["B"]',
        env: { 'A' => 'one', 'B' => 'two' }
      )
      lines = result.stdout.strip.split("\n")
      expect(lines).to eq(%w[one two])
    end

    it 'handles a command with no args as a string' do
      result = described_class.run('echo hello from shell')
      expect(result.stdout.strip).to include('hello')
    end

    it 'returns non-zero exit code for syntax errors' do
      result = described_class.run('ruby', '-e', 'invalid syntax %%%')
      expect(result.success?).to be false
      expect(result.exit_code).not_to eq(0)
    end

    it 'returns nil signal for normal exit' do
      result = described_class.run('true')
      expect(result.signal).to be_nil
    end

    context 'with signal handling' do
      it 'sends SIGTERM by default on timeout' do
        expect do
          described_class.run(
            'ruby', '-e', 'trap("TERM") { exit 143 }; sleep 60',
            timeout: 0.2
          )
        end.to raise_error(Philiprehberger::TaskRunner::TimeoutError)
      end

      it 'sends the specified signal on timeout' do
        expect do
          described_class.run(
            'ruby', '-e', 'trap("INT") { exit 130 }; sleep 60',
            timeout: 0.2,
            signal: :INT
          )
        end.to raise_error(Philiprehberger::TaskRunner::TimeoutError)
      end

      it 'escalates to SIGKILL if process does not exit after initial signal' do
        expect do
          described_class.run(
            'ruby', '-e', 'trap("TERM") { }; sleep 60',
            timeout: 0.2,
            signal: :TERM,
            kill_after: 0.3
          )
        end.to raise_error(Philiprehberger::TaskRunner::TimeoutError)
      end
    end

    context 'with stdin piping' do
      it 'pipes a string to stdin' do
        result = described_class.run('cat', stdin: 'hello from stdin')
        expect(result.stdout).to eq('hello from stdin')
      end

      it 'pipes multi-line string to stdin' do
        result = described_class.run('cat', stdin: "line1\nline2\nline3\n")
        expect(result.stdout.strip.split("\n")).to eq(%w[line1 line2 line3])
      end

      it 'pipes an IO object to stdin' do
        file = Tempfile.new('stdin_test')
        begin
          file.write('file content here')
          file.rewind
          result = described_class.run('cat', stdin: file)
          expect(result.stdout).to eq('file content here')
        ensure
          file.close
          file.unlink
        end
      end

      it 'works with nil stdin (default)' do
        result = described_class.run('echo', 'no stdin')
        expect(result.stdout.strip).to eq('no stdin')
      end

      it 'pipes stdin and captures exit code' do
        result = described_class.run('ruby', '-e', 'puts $stdin.read.upcase', stdin: 'hello')
        expect(result.stdout.strip).to eq('HELLO')
        expect(result.success?).to be true
      end

      it 'pipes empty string to stdin' do
        result = described_class.run('cat', stdin: '')
        expect(result.stdout).to eq('')
        expect(result.success?).to be true
      end

      it 'works with stdin and streaming block' do
        lines = []
        result = described_class.run('ruby', '-e', '$stdin.each_line { |l| puts l.upcase }', stdin: "abc\ndef\n") do |line|
          lines << line.strip
        end
        expect(lines).to eq(%w[ABC DEF])
        expect(result.success?).to be true
      end
    end

    context 'with block (streaming)' do
      it 'yields each line of stdout' do
        lines = []
        result = described_class.run('ruby', '-e', '3.times { |i| puts i }') { |line| lines << line.strip }
        expect(lines).to eq(%w[0 1 2])
        expect(result.success?).to be true
      end

      it 'still captures full stdout' do
        result = described_class.run('echo', 'streamed') { |_line| nil }
        expect(result.stdout.strip).to eq('streamed')
      end

      it 'still captures stderr in streaming mode' do
        result = described_class.run('ruby', '-e', '$stderr.puts "err"; puts "out"') { |_line| nil }
        expect(result.stderr.strip).to eq('err')
        expect(result.stdout.strip).to eq('out')
      end

      it 'measures duration in streaming mode' do
        result = described_class.run('true') { |_line| nil }
        expect(result.duration).to be >= 0
      end

      it 'yields lines in order' do
        lines = []
        described_class.run('ruby', '-e', '5.times { |i| puts i }') { |line| lines << line.strip }
        expect(lines).to eq(%w[0 1 2 3 4])
      end

      it 'handles streaming with no output' do
        lines = []
        result = described_class.run('true') { |line| lines << line }
        expect(lines).to be_empty
        expect(result.success?).to be true
      end

      it 'raises TimeoutError in streaming mode' do
        expect do
          described_class.run('sleep', '10', timeout: 0.2) { |_| nil }
        end.to raise_error(Philiprehberger::TaskRunner::TimeoutError)
      end

      it 'backward compatible: single-arg block only receives stdout lines' do
        lines = []
        described_class.run('ruby', '-e', 'puts "out"; $stderr.puts "err"') { |line| lines << line.strip }
        expect(lines).to eq(['out'])
      end
    end

    context 'with stderr streaming (two-arg block)' do
      it 'yields stdout lines with :stdout stream' do
        events = []
        described_class.run('ruby', '-e', 'puts "hello"') { |line, stream| events << [line.strip, stream] }
        expect(events).to include(['hello', :stdout])
      end

      it 'yields stderr lines with :stderr stream' do
        events = []
        described_class.run('ruby', '-e', '$stderr.puts "error"') { |line, stream| events << [line.strip, stream] }
        expect(events).to include(['error', :stderr])
      end

      it 'yields both stdout and stderr with correct stream identifiers' do
        events = []
        described_class.run(
          'ruby', '-e', '$stdout.puts "out"; $stdout.flush; $stderr.puts "err"; $stderr.flush'
        ) { |line, stream| events << [line.strip, stream] }
        stdout_events = events.select { |_, s| s == :stdout }
        stderr_events = events.select { |_, s| s == :stderr }
        expect(stdout_events.map(&:first)).to include('out')
        expect(stderr_events.map(&:first)).to include('err')
      end

      it 'still captures full stdout and stderr in result' do
        result = described_class.run(
          'ruby', '-e', 'puts "out"; $stderr.puts "err"'
        ) { |_line, _stream| nil }
        expect(result.stdout.strip).to eq('out')
        expect(result.stderr.strip).to eq('err')
      end

      it 'handles multiple lines on both streams' do
        events = []
        described_class.run(
          'ruby', '-e', '3.times { |i| puts "o#{i}"; $stderr.puts "e#{i}" }' # rubocop:disable Lint/InterpolationCheck
        ) { |line, stream| events << [line.strip, stream] }
        stdout_lines = events.select { |_, s| s == :stdout }.map(&:first)
        stderr_lines = events.select { |_, s| s == :stderr }.map(&:first)
        expect(stdout_lines).to eq(%w[o0 o1 o2])
        expect(stderr_lines).to eq(%w[e0 e1 e2])
      end
    end
  end

  describe Philiprehberger::TaskRunner::Result do
    it 'exposes stdout, stderr, exit_code, duration, and signal' do
      result = described_class.new(stdout: 'out', stderr: 'err', exit_code: 0, duration: 1.5, signal: :TERM)
      expect(result.stdout).to eq('out')
      expect(result.stderr).to eq('err')
      expect(result.exit_code).to eq(0)
      expect(result.duration).to eq(1.5)
      expect(result.signal).to eq(:TERM)
    end

    it 'reports success for exit code 0' do
      result = described_class.new(stdout: '', stderr: '', exit_code: 0, duration: 0.0)
      expect(result.success?).to be true
    end

    it 'reports failure for non-zero exit code' do
      result = described_class.new(stdout: '', stderr: '', exit_code: 1, duration: 0.0)
      expect(result.success?).to be false
    end

    it 'reports failure for exit code 2' do
      result = described_class.new(stdout: '', stderr: '', exit_code: 2, duration: 0.0)
      expect(result.success?).to be false
    end

    it 'reports failure for exit code 127' do
      result = described_class.new(stdout: '', stderr: '', exit_code: 127, duration: 0.0)
      expect(result.success?).to be false
    end

    it 'stores duration as a float' do
      result = described_class.new(stdout: '', stderr: '', exit_code: 0, duration: 0.001)
      expect(result.duration).to eq(0.001)
    end

    it 'defaults signal to nil' do
      result = described_class.new(stdout: '', stderr: '', exit_code: 0, duration: 0.0)
      expect(result.signal).to be_nil
    end

    it 'stores KILL signal' do
      result = described_class.new(stdout: '', stderr: '', exit_code: 137, duration: 0.0, signal: :KILL)
      expect(result.signal).to eq(:KILL)
    end
  end

  describe 'error classes' do
    it 'TimeoutError inherits from Error' do
      expect(Philiprehberger::TaskRunner::TimeoutError.ancestors).to include(Philiprehberger::TaskRunner::Error)
    end

    it 'Error inherits from StandardError' do
      expect(Philiprehberger::TaskRunner::Error.ancestors).to include(StandardError)
    end

    it 'CommandError inherits from Error' do
      expect(Philiprehberger::TaskRunner::CommandError.ancestors).to include(Philiprehberger::TaskRunner::Error)
    end
  end

  describe '.run!' do
    it 'returns Result on success' do
      result = described_class.run!('echo', 'ok')
      expect(result).to be_a(Philiprehberger::TaskRunner::Result)
      expect(result.success?).to be true
    end

    it 'raises CommandError on non-zero exit' do
      expect { described_class.run!('false') }
        .to raise_error(Philiprehberger::TaskRunner::CommandError) do |e|
          expect(e.result.exit_code).to eq(1)
          expect(e.message).to include('code 1')
        end
    end

    it 'passes options through to run' do
      result = described_class.run!('pwd', chdir: '/tmp')
      expect(result.stdout.strip).to eq('/tmp')
    end
  end

  describe 'Result#to_h' do
    it 'returns a hash with all fields' do
      result = described_class.run('echo', 'hello')
      h = result.to_h
      expect(h).to include(stdout: "hello\n", exit_code: 0, success: true, timed_out: false)
      expect(h).to have_key(:stderr)
      expect(h).to have_key(:duration)
      expect(h).to have_key(:signal)
    end
  end

  describe 'Result#failure?' do
    it 'is false for a successful exit' do
      expect(described_class.run('true').failure?).to be false
    end

    it 'is true for a non-zero exit' do
      expect(described_class.run('sh', '-c', 'exit 7').failure?).to be true
    end
  end

  describe 'Result#timed_out?' do
    it 'is false for a normal exit' do
      expect(described_class.run('true').timed_out?).to be false
    end

    it 'is true when signal is :TERM' do
      result = Philiprehberger::TaskRunner::Result.new(
        stdout: '', stderr: '', exit_code: 143, duration: 0.1, signal: :TERM
      )
      expect(result.timed_out?).to be true
    end

    it 'is true when signal is :KILL' do
      result = Philiprehberger::TaskRunner::Result.new(
        stdout: '', stderr: '', exit_code: 137, duration: 0.1, signal: :KILL
      )
      expect(result.timed_out?).to be true
    end
  end
end
