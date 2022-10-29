# frozen_string_literal: true

require 'rspec/expectations'
require 'rspec-parameterized'

require 'package_url'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec::Matchers.define :have_description do |expected|
  match do |actual|
    actual.to_s == expected
  end
end
