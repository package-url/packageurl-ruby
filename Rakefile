# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :lint do
  system 'rubocop'
end

namespace :steep do
  task :check do
    system 'steep check'
  end
end

task default: %i[lint spec steep:check]
