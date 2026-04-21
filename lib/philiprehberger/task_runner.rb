# frozen_string_literal: true

require 'open3'
require 'timeout'

require_relative 'task_runner/version'
require_relative 'task_runner/result'

module Philiprehberger
  module TaskRunner
    class Error < StandardError; end
    class TimeoutError < Error; end

    # Raised by run! when the command exits with a non-zero status.
    class CommandError < Error
      # @return [Result] the failed command result
      attr_reader :result

      def initialize(result)
        @result = result
        super("command exited with code #{result.exit_code}")
      end
    end

    # Run a shell command with output capture, optional timeout, streaming, signal handling, and stdin piping.
    #
    # When a block is given, each line of stdout/stderr is yielded as it arrives.
    # If the block accepts two arguments, it receives (line, stream) where stream is :stdout or :stderr.
    # If the block accepts one argument, it receives only the line (stdout lines only, for backward compatibility).
    #
    # @param cmd [String] the command to execute
    # @param args [Array<String>] additional command arguments
    # @param timeout [Numeric, nil] maximum seconds to wait (nil for no timeout)
    # @param env [Hash, nil] environment variables to set
    # @param chdir [String, nil] working directory for the command
    # @param signal [Symbol] signal to send on timeout (default :TERM)
    # @param kill_after [Numeric] seconds to wait before sending SIGKILL after initial signal (default 5)
    # @param stdin [String, IO, nil] data to pipe to the process's stdin
    # @yield [line, stream] each line as it arrives (streaming mode)
    # @yieldparam line [String] a line of output
    # @yieldparam stream [Symbol] :stdout or :stderr (only if block accepts 2 params)
    # @return [Result] the command result
    # @raise [TimeoutError] if the command exceeds the timeout
    def self.run(cmd, *args, timeout: nil, env: nil, chdir: nil, signal: :TERM, kill_after: 5, stdin: nil, &block)
      full_cmd = args.empty? ? cmd : [cmd, *args]
      spawn_opts = {}
      spawn_opts[:chdir] = chdir if chdir

      env_hash = env || {}
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      if block
        run_streaming(env_hash, full_cmd, spawn_opts, timeout, start_time, signal, kill_after, stdin, &block)
      else
        run_capture(env_hash, full_cmd, spawn_opts, timeout, start_time, signal, kill_after, stdin)
      end
    end

    # Run a shell command, raising CommandError on non-zero exit.
    #
    # Accepts the same arguments as {.run}.
    #
    # @return [Result] the command result
    # @raise [CommandError] if the command exits with a non-zero status
    # @raise [TimeoutError] if the command exceeds the timeout
    def self.run!(cmd, ...)
      result = run(cmd, ...)
      raise CommandError, result unless result.success?

      result
    end

    # Boolean convenience — run the command and return whether it succeeded
    # (exit code 0). Swallows `TimeoutError` (reported as false). Accepts the
    # same arguments as {.run}.
    #
    # @return [Boolean] true if the command exited with status 0
    def self.run?(cmd, ...)
      run(cmd, ...).success?
    rescue TimeoutError
      false
    end

    # @api private
    def self.run_capture(env_hash, full_cmd, spawn_opts, timeout, start_time, signal, kill_after, stdin_data)
      stdout_buf = +''
      stderr_buf = +''
      killed_signal = nil

      Open3.popen3(env_hash, *Array(full_cmd), **spawn_opts) do |stdin_io, stdout_io, stderr_io, wait_thr|
        write_stdin(stdin_io, stdin_data)

        if timeout
          begin
            ::Timeout.timeout(timeout) do
              capture_both(stdout_io, stderr_io, stdout_buf, stderr_buf)
            end
          rescue ::Timeout::Error
            killed_signal = terminate_process(wait_thr.pid, signal, kill_after)
            stdout_buf << drain_io(stdout_io)
            stderr_buf << drain_io(stderr_io)
            wait_thr.value
            Process.clock_gettime(Process::CLOCK_MONOTONIC)
            raise TimeoutError, 'command timed out'
          end
        else
          capture_both(stdout_io, stderr_io, stdout_buf, stderr_buf)
        end

        exit_status = wait_thr.value
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        Result.new(
          stdout: stdout_buf, stderr: stderr_buf,
          exit_code: exit_status.exitstatus || 1,
          duration: duration, signal: killed_signal
        )
      end
    end

    # @api private
    def self.run_streaming(env_hash, full_cmd, spawn_opts, timeout, start_time, signal, kill_after, stdin_data, &block)
      stdout_buf = +''
      stderr_buf = +''
      killed_signal = nil
      block_arity = block.arity

      Open3.popen3(env_hash, *Array(full_cmd), **spawn_opts) do |stdin_io, stdout_io, stderr_io, wait_thr|
        write_stdin(stdin_io, stdin_data)

        if timeout
          begin
            ::Timeout.timeout(timeout) do
              read_streams(stdout_io, stderr_io, stdout_buf, stderr_buf, block_arity, &block)
              wait_thr.value
            end
          rescue ::Timeout::Error
            killed_signal = terminate_process(wait_thr.pid, signal, kill_after)
            wait_thr.value
            raise TimeoutError, 'command timed out'
          end
        else
          read_streams(stdout_io, stderr_io, stdout_buf, stderr_buf, block_arity, &block)
          wait_thr.value
        end

        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        Result.new(
          stdout: stdout_buf, stderr: stderr_buf,
          exit_code: wait_thr.value.exitstatus || 1,
          duration: duration, signal: killed_signal
        )
      end
    end

    # @api private
    def self.read_streams(stdout, stderr, stdout_buf, stderr_buf, block_arity)
      two_arg = block_arity == 2
      threads = []
      threads << Thread.new do
        stdout.each_line do |line|
          stdout_buf << line
          if two_arg
            yield line, :stdout
          else
            yield line
          end
        end
      end
      threads << Thread.new do
        stderr.each_line do |line|
          stderr_buf << line
          yield line, :stderr if two_arg
        end
      end
      threads.each(&:join)
    end

    # @api private
    def self.capture_both(stdout_io, stderr_io, stdout_buf, stderr_buf)
      stderr_thread = Thread.new { stderr_buf << stderr_io.read }
      stdout_buf << stdout_io.read
      stderr_thread.join
    end

    # @api private
    def self.write_stdin(stdin_io, stdin_data)
      if stdin_data.nil?
        stdin_io.close
      elsif stdin_data.respond_to?(:read)
        IO.copy_stream(stdin_data, stdin_io)
        stdin_io.close
      else
        stdin_io.write(stdin_data.to_s)
        stdin_io.close
      end
    end

    # @api private
    # Sends the specified signal, waits kill_after seconds, then sends SIGKILL if needed.
    # Returns the signal that actually killed the process.
    def self.terminate_process(pid, signal, kill_after)
      begin
        Process.kill(signal.to_s, pid)
      rescue Errno::ESRCH
        return nil
      end

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + kill_after
      loop do
        begin
          Process.kill(0, pid)
        rescue Errno::ESRCH
          return signal
        end
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep(0.05)
      end

      begin
        Process.kill('KILL', pid)
        :KILL
      rescue Errno::ESRCH
        signal
      end
    end

    # @api private
    def self.drain_io(io)
      io.read_nonblock(1_048_576)
    rescue IO::WaitReadable, IOError
      ''
    end

    private_class_method :run_capture, :run_streaming, :read_streams, :capture_both, :write_stdin, :terminate_process,
                         :drain_io
  end
end
