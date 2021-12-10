# frozen_string_literal: true

require_relative 'lib/package_url/version'

Gem::Specification.new do |spec|
  spec.name          = 'packageurl-ruby'
  spec.version       = PackageURL::VERSION
  spec.authors       = ['Mattt']
  spec.email         = ['mattt@me.com']

  spec.summary       = 'Ruby implementation of the package url spec'
  spec.description   = <<-DESCRIPTION
    A package URL, or purl, is a URL string used to
    identify and locate a software package in a mostly universal and uniform way
    across programing languages, package managers, packaging conventions,
    tools, APIs and databases.
  DESCRIPTION

  spec.homepage = 'https://github.com/package-url/packageurl-ruby'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')

  spec.license = 'MIT'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata = {
    'rubygems_mfa_required' => 'true'
  }
end
