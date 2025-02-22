# frozen_string_literal: true

module Philiprehberger
  module TaskRunner
    # Represents the result of a shell command execution.
    class Result
      # @return [String] standard output
      attr_reader :stdout

      # @return [String] standard error
      attr_reader :stderr

      # @return [Integer] process exit code
      attr_reader :exit_code

      # @return [Float] execution duration in seconds
      attr_reader :duration

      # @return [Symbol, nil] signal that killed the process (:TERM, :KILL, or nil)
      attr_reader :signal

      # @param stdout [String]
      # @param stderr [String]
      # @param exit_code [Integer]
      # @param duration [Float]
      # @param signal [Symbol, nil]
      def initialize(stdout:, stderr:, exit_code:, duration:, signal: nil)
        @stdout = stdout
        @stderr = stderr
        @exit_code = exit_code
        @duration = duration
        @signal = signal
      end

      # Whether the command exited successfully.
      #
      # @return [Boolean]
      def success?
        @exit_code.zero?
      end

      # Hash representation of the result.
      #
      # @return [Hash]
      def to_h
        {
          stdout: @stdout,
          stderr: @stderr,
          exit_code: @exit_code,
          duration: @duration,
          signal: @signal,
          success: success?
        }
      end
    end
  end
end
