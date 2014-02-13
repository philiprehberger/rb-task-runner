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
      expect(result.stdout.strip).to eq('/')
    end

    it 'raises TimeoutError when command exceeds timeout' do
      expect do
        described_class.run('sleep', '10', timeout: 0.1)
      end.to raise_error(Philiprehberger::TaskRunner::TimeoutError)
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
  end
end
