# packageurl-ruby

![CI][ci badge]

A Ruby implementation of the [package url specification][purl-spec].

## Requirements

- Ruby 2.7+

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'packageurl-ruby'
```

And then execute:

```console
$ bundle install
```

Or install it yourself as:

```console
$ gem install packageurl-ruby
```

## Usage

```ruby
require 'package_url'

purl = PackageURL.parse("pkg:gem/rails@6.1.4")
purl.type # "gem"
purl.name # "rails"
purl.version # "6.1.4"

# supports pattern matching with hashes and arrays
case purl
in type: 'gem', name: 'rails'
  puts 'Yay! You’re on Rails!'
in ['pkg', 'gem', *]
  puts '🦊🗯 "Ruby is easy to read"'
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. 
Then, run `rake spec` to run the tests. 
You can also run `bin/console` for an interactive prompt 
that will allow you to experiment.

To install this gem onto your local machine, 
run `bundle exec rake install`. 
To release a new version, 
update the version number in `version.rb`, 
and then run `bundle exec rake release`, 
which will create a git tag for the version, 
push git commits and the created tag, 
and push the `.gem` file to [rubygems.org](https://rubygems.org).

[ci badge]: https://github.com/mattt/packageurl-ruby/workflows/CI/badge.svg
[purl-spec]: https://github.com/package-url/purl-spec
