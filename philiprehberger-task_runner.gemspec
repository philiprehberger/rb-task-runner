# frozen_string_literal: true

require_relative 'lib/philiprehberger/task_runner/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-task_runner'
  spec.version       = Philiprehberger::TaskRunner::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Shell command runner with output capture, timeout, and streaming'
  spec.description   = 'Run shell commands with captured stdout/stderr, exit code, duration measurement, ' \
                       'configurable timeout, environment variables, and line-by-line streaming via blocks.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-task-runner'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
