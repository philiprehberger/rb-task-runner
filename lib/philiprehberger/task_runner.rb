# frozen_string_literal: true

require 'open3'
require 'timeout'

require_relative 'task_runner/version'
require_relative 'task_runner/result'

module Philiprehberger
  module TaskRunner
    class Error < StandardError; end
    class TimeoutError < Error; end

    # Run a shell command with output capture, optional timeout, and streaming.
    #
    # When a block is given, each line of stdout is yielded as it arrives.
    #
    # @param cmd [String] the command to execute
    # @param args [Array<String>] additional command arguments
    # @param timeout [Numeric, nil] maximum seconds to wait (nil for no timeout)
    # @param env [Hash, nil] environment variables to set
    # @param chdir [String, nil] working directory for the command
    # @yield [line] each line of stdout as it arrives (streaming mode)
    # @yieldparam line [String] a line of output
    # @return [Result] the command result
    # @raise [TimeoutError] if the command exceeds the timeout
    def self.run(cmd, *args, timeout: nil, env: nil, chdir: nil, &block)
      full_cmd = args.empty? ? cmd : [cmd, *args]
      spawn_opts = {}
      spawn_opts[:chdir] = chdir if chdir

      env_hash = env || {}
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      if block
        run_streaming(env_hash, full_cmd, spawn_opts, timeout, start_time, &block)
      else
        run_capture(env_hash, full_cmd, spawn_opts, timeout, start_time)
      end
    end

    # @api private
    def self.run_capture(env_hash, full_cmd, spawn_opts, timeout, start_time)
      stdout, stderr, status = if timeout
                                 ::Timeout.timeout(timeout, TimeoutError, 'command timed out') do
                                   Open3.capture3(env_hash, *Array(full_cmd), **spawn_opts)
                                 end
                               else
                                 Open3.capture3(env_hash, *Array(full_cmd), **spawn_opts)
                               end

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      Result.new(stdout: stdout, stderr: stderr, exit_code: status.exitstatus || 1, duration: duration)
    end

    # @api private
    def self.run_streaming(env_hash, full_cmd, spawn_opts, timeout, start_time, &block)
      stdout_buf = +''
      stderr_buf = +''
      exit_status = nil

      Open3.popen3(env_hash, *Array(full_cmd), **spawn_opts) do |_stdin, stdout, stderr, wait_thr|
        _stdin.close

        if timeout
          ::Timeout.timeout(timeout, TimeoutError, 'command timed out') do
            read_streams(stdout, stderr, stdout_buf, stderr_buf, &block)
            exit_status = wait_thr.value
          end
        else
          read_streams(stdout, stderr, stdout_buf, stderr_buf, &block)
          exit_status = wait_thr.value
        end
      end

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      Result.new(
        stdout: stdout_buf,
        stderr: stderr_buf,
        exit_code: exit_status&.exitstatus || 1,
        duration: duration
      )
    end

    # @api private
    def self.read_streams(stdout, stderr, stdout_buf, stderr_buf)
      threads = []
      threads << Thread.new do
        stdout.each_line do |line|
          stdout_buf << line
          yield line
        end
      end
      threads << Thread.new do
        stderr_buf << stderr.read
      end
      threads.each(&:join)
    end

    private_class_method :run_capture, :run_streaming, :read_streams
  end
end
