# frozen_string_literal: true

require_relative 'string_utils'

require 'uri'

class PackageURL
  class Encoder
    include StringUtils

    def initialize(package)
      @type = package.type
      @namespace = package.namespace
      @name = package.name
      @version = package.version
      @qualifiers = package.qualifiers
      @subpath = package.subpath
    end

    def encode
      encode_scheme!
      encode_type!
      encode_name!
      encode_version!
      encode_qualifiers!
      encode_subpath!

      @purl
    end

    private

    def encode_scheme!
      @purl = 'pkg:'
    end

    def encode_type!
      # Append the type string to the purl as a lowercase ASCII string
      # Append '/' to the purl
      @purl += @type
      @purl += '/'
    end

    def encode_name!
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
        @purl += URI.encode_www_form_component(@name)
      else
        @purl += encode_segments(@namespace, &:empty?)
        @purl += '/'
        @purl += URI.encode_www_form_component(strip(@name, '/'))
      end
    end

    def encode_version!
      return if @version.nil?

      # - Append '@' to the purl
      # - UTF-8-encode the version if needed in your programming language
      # - Append the percent-encoded version to the purl
      @purl += '@'
      @purl += URI.encode_www_form_component(@version)
    end

    def encode_qualifiers!
      return if @qualifiers.nil? || encoded_qualifiers.empty?

      @purl += '?'
      @purl += encoded_qualifiers
    end

    def encoded_qualifiers
      @encoded_qualifiers ||= @qualifiers.filter_map do |key, value|
        next if value.empty?

        next "#{key.downcase}=#{value.join(',')}" if key == 'checksums' && value.is_a?(::Array)

        "#{key.downcase}=#{URI.encode_www_form_component(value)}"
      end.sort.join('&')
    end

    def encode_subpath!
      return if @subpath.nil? || encoded_subpath.empty?

      @purl += '#'
      @purl += encoded_subpath
    end

    def encoded_subpath
      @encoded_subpath ||= encode_segments(@subpath) do |segment|
        # Discard segments which are blank, `.`, or `..`
        segment.empty? || segment == '.' || segment == '..'
      end
    end
  end
end
