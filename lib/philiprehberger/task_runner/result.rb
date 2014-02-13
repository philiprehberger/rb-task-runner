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

      # @param stdout [String]
      # @param stderr [String]
      # @param exit_code [Integer]
      # @param duration [Float]
      def initialize(stdout:, stderr:, exit_code:, duration:)
        @stdout = stdout
        @stderr = stderr
        @exit_code = exit_code
        @duration = duration
      end

      # Whether the command exited successfully.
      #
      # @return [Boolean]
      def success?
        @exit_code == 0
      end
    end
  end
end
