# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::TaskRunner do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::TaskRunner::VERSION).not_to be_nil
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
        described_class.run('sleep', '10', timeout: 0.1)
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

    it 'returns exit code 1 for syntax errors' do
      result = described_class.run('ruby', '-e', 'invalid syntax %%%')
      expect(result.success?).to be false
      expect(result.exit_code).not_to eq(0)
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
          described_class.run('sleep', '10', timeout: 0.1) { |_| nil }
        end.to raise_error(Philiprehberger::TaskRunner::TimeoutError)
      end
    end
  end

  describe Philiprehberger::TaskRunner::Result do
    it 'exposes stdout, stderr, exit_code, and duration' do
      result = described_class.new(stdout: 'out', stderr: 'err', exit_code: 0, duration: 1.5)
      expect(result.stdout).to eq('out')
      expect(result.stderr).to eq('err')
      expect(result.exit_code).to eq(0)
      expect(result.duration).to eq(1.5)
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
  end

  describe 'error classes' do
    it 'TimeoutError inherits from Error' do
      expect(Philiprehberger::TaskRunner::TimeoutError.ancestors).to include(Philiprehberger::TaskRunner::Error)
    end

    it 'Error inherits from StandardError' do
      expect(Philiprehberger::TaskRunner::Error.ancestors).to include(StandardError)
    end
  end
end
