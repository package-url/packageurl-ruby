# frozen_string_literal: true

require_relative 'package_url/version'

require 'uri'

# A package URL, or _purl_, is a URL string used to
# identify and locate a software package in a mostly universal and uniform way
# across programing languages, package managers, packaging conventions, tools,
# APIs and databases.
#
# A purl is a URL composed of seven components:
#
# ```
# scheme:type/namespace/name@version?qualifiers#subpath
# ```
#
# For example,
# the package URL for this Ruby package at version 0.1.0 is
# `pkg:ruby/mattt/packageurl-ruby@0.1.0`.
class PackageURL
  # Raised when attempting to parse an invalid package URL string.
  # @see #parse
  class InvalidPackageURL < ArgumentError; end

  # The URL scheme, which has a constant value of `"pkg"`.
  def scheme
    'pkg'
  end

  # The package type or protocol, such as `"gem"`, `"npm"`, and `"github"`.
  attr_reader :type

  # A name prefix, specific to the type of package.
  # For example, an npm scope, a Docker image owner, or a GitHub user.
  attr_reader :namespace

  # The name of the package.
  attr_reader :name

  # The version of the package.
  attr_reader :version

  # Extra qualifying data for a package, specific to the type of package.
  # For example, the operating system or architecture.
  attr_reader :qualifiers

  # An extra subpath within a package, relative to the package root.
  attr_reader :subpath

  # Constructs a package URL from its components
  # @param type [String] The package type or protocol.
  # @param namespace [String] A name prefix, specific to the type of package.
  # @param name [String] The name of the package.
  # @param version [String] The version of the package.
  # @param qualifiers [Hash] Extra qualifying data for a package, specific to the type of package.
  # @param subpath [String] An extra subpath within a package, relative to the package root.
  def initialize(type:, name:, namespace: nil, version: nil, qualifiers: nil, subpath: nil)
    raise ArgumentError, 'type is required' if type.nil? || type.empty?
    raise ArgumentError, 'name is required' if name.nil? || name.empty?

    @type = type.downcase
    @namespace = namespace
    @name = name
    @version = version
    @qualifiers = qualifiers
    @subpath = subpath
  end

  # Creates a new PackageURL from a string.
  # @param [String] string The package URL string.
  # @raise [InvalidPackageURL] If the string is not a valid package URL.
  # @return [PackageURL]
  def self.parse(string)
    components = {}

    # Split the purl string once from right on '#'
    # - The left side is the remainder
    # - The right side will be parsed as the subpath
    components[:subpath], string = partition(string, '#', from: :right) do |subpath|
      parse_subpath(subpath)
    end

    # Split the remainder once from right on '?'
    # - The left side is the remainder
    # - The right side is the qualifiers string
    components[:qualifiers], string = partition(string, '?', from: :right) do |qualifiers|
      parse_qualifiers(qualifiers)
    end

    # Split the remainder once from left on ':'
    # - The left side lowercased is the scheme
    # - The right side is the remainder
    scheme, string = partition(string, ':', from: :left)
    raise InvalidPackageURL, 'invalid or missing "pkg:" URL scheme' unless scheme == 'pkg'

    # Strip the remainder from leading and trailing '/'
    # - Split this once from left on '/'
    # - The left side lowercased is the type
    # - The right side is the remainder
    string = string.delete_suffix('/')
    components[:type], string = partition(string, '/', from: :left)
    raise InvalidPackageURL, 'invalid or missing package type' if components[:type].empty?

    # Split the remainder once from right on '@'
    # - The left side is the remainder
    # - Percent-decode the right side. This is the version.
    # - UTF-8-decode the version if needed in your programming language
    # - This is the version
    components[:version], string = partition(string, '@', from: :right) do |version|
      URI.decode_www_form_component(version)
    end

    # Split the remainder once from right on '/'
    # - The left side is the remainder
    # - Percent-decode the right side. This is the name
    # - UTF-8-decode this name if needed in your programming language
    # - Apply type-specific normalization to the name if needed
    # - This is the name
    components[:name], string = partition(string, '/', from: :right, require_separator: false) do |name|
      URI.decode_www_form_component(name)
    end

    components[:namespace] = parse_namespace(string) unless string.empty?

    new(type: components[:type],
        name: components[:name],
        namespace: components[:namespace],
        version: components[:version],
        qualifiers: components[:qualifiers],
        subpath: components[:subpath])
  end

  # Returns a hash containing the
  # scheme, type, namespace, name, version, qualifiers, and subpath components
  # of the package URL.
  def to_h
    {
      scheme: scheme,
      type: @type,
      namespace: @namespace,
      name: @name,
      version: @version,
      qualifiers: @qualifiers,
      subpath: @subpath
    }
  end

  # Returns a string representation of the package URL.
  # Package URL representations are created according to the instructions from
  # https://github.com/package-url/purl-spec/blob/0b1559f76b79829e789c4f20e6d832c7314762c5/PURL-SPECIFICATION.rst#how-to-build-purl-string-from-its-components.
  def to_s
    # Start a purl string with the "pkg:" scheme as a lowercase ASCII string
    purl = 'pkg:'

    # Append the type string to the purl as a lowercase ASCII string
    # Append '/' to the purl

    purl += @type
    purl += '/'

    # If the namespace is empty:
    # - Apply type-specific normalization to the name if needed
    # - UTF-8-encode the name if needed in your programming language
    # - Append the percent-encoded name to the purl
    #
    # If the namespace is not empty:
    # - Strip the namespace from leading and trailing '/'
    # - Split on '/' as segments
    # - Apply type-specific normalization to each segment if needed
    # - UTF-8-encode each segment if needed in your programming language
    # - Percent-encode each segment
    # - Join the segments with '/'
    # - Append this to the purl
    # - Append '/' to the purl
    # - Strip the name from leading and trailing '/'
    # - Apply type-specific normalization to the name if needed
    # - UTF-8-encode the name if needed in your programming language
    # - Append the percent-encoded name to the purl
    if @namespace.nil?
      purl += URI.encode_www_form_component(@name)
    else
      purl += serialized_namespace
      purl += '/'
      purl += URI.encode_www_form_component(self.class.strip(@name, '/'))
    end

    # If the version is not empty:
    # - Append '@' to the purl
    # - UTF-8-encode the version if needed in your programming language
    # - Append the percent-encoded version to the purl
    unless @version.nil?
      purl += '@'
      purl += URI.encode_www_form_component(@version)
    end

    # If the qualifiers are not empty and not composed only of key/value pairs
    # where the value is empty:
    # - Append '?' to the purl
    # - Build a list from all key/value pair:
    # - discard any pair where the value is empty.
    # - UTF-8-encode each value if needed in your programming language
    # - If the key is checksums and this is a list of checksums
    #   join this list with a ',' to create this qualifier value
    # - create a string by joining the lowercased key,
    #   the equal '=' sign and the percent-encoded value to create a qualifier
    # - sort this list of qualifier strings lexicographically
    # - join this list of qualifier strings with a '&' ampersand
    # - Append this string to the purl
    unless (qualifiers = serialized_qualifiers).empty?
      purl += '?'
      purl += qualifiers
    end

    # If the subpath is not empty and not composed only of
    # empty, '.' and '..' segments:
    # - Append '#' to the purl
    # - Strip the subpath from leading and trailing '/'
    # - Split this on '/' as segments
    # - Discard empty, '.' and '..' segments
    # - Percent-encode each segment
    # - UTF-8-encode each segment if needed in your programming language
    # - Join the segments with '/'
    # - Append this to the purl
    unless (subpath = serialized_subpath).empty?
      purl += '#'
      purl += subpath
    end

    purl
  end

  # Returns an array containing the
  # scheme, type, namespace, name, version, qualifiers, and subpath components
  # of the package URL.
  def deconstruct
    [scheme, @type, @namespace, @name, @version, @qualifiers, @subpath]
  end

  # Returns a hash containing the
  # scheme, type, namespace, name, version, qualifiers, and subpath components
  # of the package URL.
  def deconstruct_keys(_keys)
    to_h
  end

  class << self
    def strip(string, char)
      string.delete_prefix(char).delete_suffix(char)
    end

    def parse_segments(string)
      strip(string, '/').split('/')
    end

    def segment_present?(segment)
      !segment.empty? && segment != '.' && segment != '..'
    end

    private

    def partition(string, sep, from: :left, require_separator: true)
      value, separator, remainder = if from == :left
                                      left, separator, right = string.partition(sep)
                                      [left, separator, right]
                                    else
                                      left, separator, right = string.rpartition(sep)
                                      [right, separator, left]
                                    end

      return [nil, value] if separator.empty? && require_separator

      value = yield(value, remainder) if block_given?

      [value, remainder]
    end

    def parse_subpath(subpath)
      # - Split the subpath on '/'
      # - Discard any empty string segment from that split
      # - Discard any '.' or '..' segment from that split
      # - Percent-decode each segment
      # - UTF-8-decode each segment if needed in your programming language
      # - Join segments back with a '/'
      # - This is the subpath
      subpath.split('/').filter_map do |segment|
        next unless segment_present?(segment)

        URI.decode_www_form_component(segment)
      end.compact.join('/')
    end

    def parse_qualifiers(raw_qualifiers)
      # - Split the qualifiers on '&'. Each part is a key=value pair
      # - For each pair, split the key=value once from left on '=':
      # - The key is the lowercase left side
      # - The value is the percent-decoded right side
      # - UTF-8-decode the value if needed in your programming language
      # - Discard any key/value pairs where the value is empty
      # - If the key is checksums,
      #   split the value on ',' to create a list of checksums
      # - This list of key/value is the qualifiers object
      raw_qualifiers.split('&').each_with_object({}) do |pair, memo|
        key, separator, value = pair.partition('=')

        next if separator.empty?

        key = key.downcase
        value = URI.decode_www_form_component(value)

        next if value.empty?

        case key
        when 'checksums'
          memo[key] = value.split(',')
        else
          memo[key] = value
        end
      end
    end

    def parse_namespace(namespace)
      # Split the remainder on '/'
      # - Discard any empty segment from that split
      # - Percent-decode each segment
      # - UTF-8-decode the each segment if needed in your programming language
      # - Apply type-specific normalization to each segment if needed
      # - Join segments back with a '/'
      # - This is the namespace
      namespace.split('/').filter_map do |s|
        next unless segment_present?(s)

        URI.decode_www_form_component(s)
      end.compact.join('/')
    end
  end

  private

  def serialized_subpath
    return '' if subpath.nil?

    self.class.parse_segments(subpath).map do |segment|
      next unless self.class.segment_present?(segment)

      URI.encode_www_form_component(segment)
    end.join('/')
  end

  def serialized_qualifiers
    return '' if qualifiers.nil?

    qualifiers.map do |key, value|
      next if value.empty?

      next "#{key.downcase}=#{value.join(',')}" if key == 'checksums'

      "#{key.downcase}=#{URI.encode_www_form_component(value)}"
    end.sort.join('&')
  end

  def serialized_namespace
    self.class.parse_segments(namespace).map do |segment|
      next if segment.empty?

      URI.encode_www_form_component(segment)
    end.join('/')
  end
end
