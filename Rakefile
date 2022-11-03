# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'open-uri'

require 'rake/clean'

RSpec::Core::RakeTask.new(:spec, [] => ['spec/fixtures/test-suite-data.json'])

directory 'spec/fixtures/'
file 'spec/fixtures/test-suite-data.json' => 'spec/fixtures/' do |t|
  File.open(t.name, 'wb') do |file|
    URI.open('https://raw.githubusercontent.com/package-url/purl-spec/master/test-suite-data.json') do |uri|
      file.write(uri.read)
    end
  end
end

CLOBBER << 'spec/fixtures/test-suite-data.json'

task :lint do
  system 'rubocop'
end

namespace :steep do
  task :check do
    system 'steep check'
  end
end

task default: %i[lint spec steep:check]
