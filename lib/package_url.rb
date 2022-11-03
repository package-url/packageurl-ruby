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
# ``
# scheme:type/namespace/name@version?qualifiers#subpath
# ``
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
    # - Strip the right side from leading and trailing '/'
    # - Split this on '/'
    # - Discard any empty string segment from that split
    # - Discard any '.' or '..' segment from that split
    # - Percent-decode each segment
    # - UTF-8-decode each segment if needed in your programming language
    # - Join segments back with a '/'
    # - This is the subpath
    case string.rpartition('#')
    in String => remainder, separator, String => subpath unless separator.empty?
      components[:subpath] = subpath.split('/').select do |segment|
        !segment.empty? && segment != '.' && segment != '..'
      end.compact.join('/')

      string = remainder
    else
      components[:subpath] = nil
    end

    # Split the remainder once from right on '?'
    # - The left side is the remainder
    # - The right side is the qualifiers string
    # - Split the qualifiers on '&'. Each part is a key=value pair
    # - For each pair, split the key=value once from left on '=':
    # - The key is the lowercase left side
    # - The value is the percent-decoded right side
    # - UTF-8-decode the value if needed in your programming language
    # - Discard any key/value pairs where the value is empty
    # - If the key is checksums,
    #   split the value on ',' to create a list of checksums
    # - This list of key/value is the qualifiers object
    case string.rpartition('?')
    in String => remainder, separator, String => qualifiers unless separator.empty?
      components[:qualifiers] = {}

      qualifiers.split('&').each do |pair|
        case pair.partition('=')
        in String => key, separator, String => value unless separator.empty?
          key = key.downcase
          value = URI.decode_www_form_component(value)
          next if value.empty?

          case key
          when 'checksums'
            components[:qualifiers][key] = value.split(',')
          else
            components[:qualifiers][key] = value
          end
        else
          next
        end
      end

      string = remainder
    else
      components[:qualifiers] = nil
    end

    # Split the remainder once from left on ':'
    # - The left side lowercased is the scheme
    # - The right side is the remainder
    # purl parsers must accept URLs such as 'pkg://' and must ignore the '//'.
    case string.partition(%r{:/*})
    in 'pkg', separator, String => remainder unless separator.empty?
      string = remainder
    else
      raise InvalidPackageURL, 'invalid or missing "pkg:" URL scheme'
    end

    # Strip the remainder from leading and trailing '/'
    # - Split this once from left on '/'
    # - The left side lowercased is the type
    # - The right side is the remainder
    string = string.delete_suffix('/')
    case string.partition('/')
    in String => type, separator, remainder unless separator.empty?
      components[:type] = type

      string = remainder
    else
      raise InvalidPackageURL, 'invalid or missing package type'
    end

    # Split the remainder once from right on '@'
    # - The left side is the remainder
    # - Percent-decode the right side. This is the version.
    # - UTF-8-decode the version if needed in your programming language
    # - This is the version
    case string.rpartition('@')
    in String => remainder, separator, String => version unless separator.empty?
      components[:version] = URI.decode_www_form_component(version)

      string = remainder
    else
      components[:version] = nil
    end

    # Split the remainder once from right on '/'
    # - The left side is the remainder
    # - Percent-decode the right side. This is the name
    # - UTF-8-decode this name if needed in your programming language
    # - Apply type-specific normalization to the name if needed
    # - This is the name
    case string.rpartition('/')
    in String => remainder, separator, String => name unless separator.empty?
      components[:name] = URI.decode_www_form_component(name)

      # Split the remainder on '/'
      # - Discard any empty segment from that split
      # - Percent-decode each segment
      # - UTF-8-decode the each segment if needed in your programming language
      # - Apply type-specific normalization to each segment if needed
      # - Join segments back with a '/'
      # - This is the namespace
      components[:namespace] = remainder.split('/').map { |s| URI.decode_www_form_component(s) }.compact.join('/')
    in _, _, String => name
      components[:name] = URI.decode_www_form_component(name)
      components[:namespace] = nil
    end

    begin
      purl = new(type: components[:type],
                 name: components[:name],
                 namespace: components[:namespace],
                 version: components[:version],
                 qualifiers: components[:qualifiers],
                 subpath: components[:subpath])

      if rules = TYPES[purl.type]
        rules.call(purl)
      end

      purl.validate!
    rescue ArgumentError => e
      raise InvalidPackageURL, e.message
    end
  end

  def validate!
    # A `purl` string is an ASCII URL string composed of seven components.
    #
    # Some components are allowed to use other characters beyond ASCII:
    # these components must then be UTF-8-encoded strings
    # and percent-encoded as defined in the "Character encoding" section.
    #
    # The rules for each component are:

    # - **scheme**:
    #   - The `scheme` is a constant with the value "pkg"
    raise InvalidPackageURL, 'scheme must be "pkg"' unless scheme == 'pkg'

    # - **type**:
    #   - The package `type` is composed only of ASCII letters and numbers, '.', '+'
    #     and '-' (period, plus, and dash)
    #   - The `type` cannot start with a number
    #   - The `type` cannot contains spaces
    #   - The `type` must NOT be percent-encoded
    #   - The `type` is case insensitive. The canonical form is lowercase
    unless type =~ /\A[a-z0-9][a-z0-9.+\-]*\z/
      raise InvalidPackageURL,
            'type must be composed only of ASCII letters and numbers, ".", "+", and "-" (period, plus, and dash)'
    end

    # - **namespace**:
    #   - The optional `namespace` contains zero or more segments, separated by slash
    #     '/'
    #   - Leading and trailing slashes '/' are not significant and should be stripped
    #     in the canonical form. They are not part of the `namespace`
    #   - Each `namespace` segment must be a percent-encoded string
    #   - When percent-decoded, a segment:
    #     - must not contain a '/'
    #     - must not be empty
    #   - A URL host or Authority must NOT be used as a `namespace`. Use instead a
    #     `repository_url` qualifier. Note however that for some types, the
    #     `namespace` may look like a host.
    namespace&.split('/')&.each do |segment|
      raise InvalidPackageURL, 'namespace cannot contain empty segments' if segment.empty?
    end

    # - **name**:
    #   - The `name` is prefixed by a '/' separator when the `namespace` is not empty
    #   - This '/' is not part of the `name`
    #   - A `name` must be a percent-encoded string
    raise InvalidPackageURL, 'name must be percent-encoded' if name && name =~ /%[0-9a-f]{2}/i

    # - **version**:
    #   - The `version` is prefixed by a '@' separator when not empty
    #   - This '@' is not part of the `version`
    #   - A `version` must be a percent-encoded string
    #   - A `version` is a plain and opaque string. Some package `types` use versioning
    #     conventions such as semver for NPMs or nevra conventions for RPMS. A `type`
    #     may define a procedure to compare and sort versions, but there is no
    #     reliable and uniform way to do such comparison consistently.
    raise InvalidPackageURL, 'version must be percent-encoded' if version && version =~ /%[0-9a-f]{2}/i

    # - **qualifiers**:
    #   - The `qualifiers` string is prefixed by a '?' separator when not empty
    #   - This '?' is not part of the `qualifiers`
    #   - This is a query string composed of zero or more `key=value` pairs each
    #     separated by a '&' ampersand. A `key` and `value` are separated by the equal
    #     '=' character
    #   - These '&' are not part of the `key=value` pairs.
    #   - `key` must be unique within the keys of the `qualifiers` string
    #   - `value` cannot be an empty string: a `key=value` pair with an empty `value`
    #     is the same as no key/value at all for this key
    #   - For each pair of `key` = `value`:
    #     - The `key` must be composed only of ASCII letters and numbers, '.', '-' and
    #       '_' (period, dash and underscore)
    #     - A `key` cannot start with a number
    #     - A `key` must NOT be percent-encoded
    #     - A `key` is case insensitive. The canonical form is lowercase
    #     - A `key` cannot contains spaces
    #     - A `value` must be a percent-encoded string
    #     - The '=' separator is neither part of the `key` nor of the `value`
    qualifiers&.each do |key, _value|
      raise InvalidPackageURL, 'qualifiers cannot contain empty keys' if key.empty?

      unless key =~ /\A[a-z0-9][a-z0-9.\-_]*\z/
        raise InvalidPackageURL,
              'qualifier keys must be composed only of ASCII letters and numbers, ".", "-", and "_" (period, dash, and underscore)'
      end

      raise InvalidPackageURL, 'qualifier keys must not be percent-encoded' if key =~ /%[0-9a-f]{2}/i
      raise InvalidPackageURL, 'qualifier keys must not contain spaces' if key =~ /\s/
      raise InvalidPackageURL, 'qualifier keys must not start with a number' if key =~ /\A\d/
    end

    # - **subpath**:
    #   - The `subpath` string is prefixed by a '#' separator when not empty
    #   - This '#' is not part of the `subpath`
    #   - The `subpath` contains zero or more segments, separated by slash '/'
    #   - Leading and trailing slashes '/' are not significant and should be stripped
    #     in the canonical form
    #   - Each `subpath` segment must be a percent-encoded string
    #   - When percent-decoded, a segment:
    #     - must not contain a '/'
    #     - must not be any of '..' or '.'
    #     - must not be empty
    #   - The `subpath` must be interpreted as relative to the root of the package
    subpath&.split('/')&.each do |segment|
      raise InvalidPackageURL, 'subpath cannot contain empty segments' if segment.empty?
      raise InvalidPackageURL, 'subpath cannot contain "."' if segment == '.'
      raise InvalidPackageURL, 'subpath cannot contain ".."' if segment == '..'
    end

    self
  end

  def valid?
    validate!
    true
  rescue InvalidPackageURL
    false
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
    #
    # If the namespace is empty:
    # - Apply type-specific normalization to the name if needed
    # - UTF-8-encode the name if needed in your programming language
    # - Append the percent-encoded name to the purl
    case @namespace
    in String => namespace unless namespace.empty?
      segments = []
      @namespace.delete_prefix('/').delete_suffix('/').split('/').each do |segment|
        next if segment.empty?

        segments << encode(segment)
      end
      purl += segments.join('/')

      purl += '/'
      purl += encode(@name.delete_prefix('/').delete_suffix('/'))
    else
      purl += encode(@name)
    end

    # If the version is not empty:
    # - Append '@' to the purl
    # - UTF-8-encode the version if needed in your programming language
    # - Append the percent-encoded version to the purl
    case @version
    in String => version unless version.empty?
      purl += '@'
      purl += encode(@version)
    else
      nil
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
    case @qualifiers
    in Hash => qualifiers unless qualifiers.empty?
      list = []
      qualifiers.each do |key, value|
        next if value.empty?

        case [key, value]
        in 'checksums', Array => checksums
          list << "#{key.downcase}=#{checksums.join(',')}"
        else
          list << "#{key.downcase}=#{encode(value)}"
        end
      end

      unless list.empty?
        purl += '?'
        purl += list.sort.join('&')
      end
    else
      nil
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
    case @subpath
    in String => subpath unless subpath.empty?
      segments = []
      subpath.delete_prefix('/').delete_suffix('/').split('/').each do |segment|
        next if segment.empty? || segment == '.' || segment == '..'

        segments << encode(segment)
      end

      unless segments.empty?
        purl += '#'
        purl += segments.join('/')
      end
    else
      nil
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

  TYPES = {
    # `alpm` for Arch Linux and other users of the libalpm/pacman package manager.
    #
    # - There is no default package repository: this should be implied either from
    #   the `distro` qualifiers key  or using a repository base url as
    #   `repository_url` qualifiers key.
    # - The `namespace` is the vendor such as `arch`, `arch32`, `archarm`,
    #   `manjaro` or `msys`. It is not case sensitive and must be lowercased.
    # - The `name` is the package name. It is not case sensitive and must be lowercased.
    # - The `version` is the version of the package as specified in [`vercmp(8)`](https://man.archlinux.org/man/vercmp.8#DESCRIPTION) as part of alpm.
    # - The `arch` is the qualifiers key for a package architecture.
    #
    # Examples:
    #    pkg:alpm/arch/pacman@6.0.1-1?arch=x86_64
    #    pkg:alpm/arch/python-pip@21.0-1?arch=any
    #    pkg:alpm/arch/containers-common@1:0.47.4-4?arch=x86_64
    'alpm' => lambda { |purl|
                purl&.namespace&.downcase!
                purl&.name&.downcase!
              },

    # `bitbucket` for Bitbucket-based packages:
    #
    # - The default repository is `https://bitbucket.org`
    # - The `namespace` is the user or organization. It is not case sensitive and
    #  must be lowercased.
    # - The `name` is the repository name. It is not case sensitive and must be
    #  lowercased.
    # - The `version` is a commit or tag
    #
    # Examples:
    #    pkg:bitbucket/birkenfeld/pygments-main@244fd47e07d1014f0aed9c
    'bitbucket' => lambda { |purl|
                     purl&.namespace&.downcase!
                     purl&.name&.downcase!
                   },

    # `cocoapods` for Cocoapods:
    #
    # - The default repository is `https://cdn.cocoapods.org/`
    # - The `name` is the pod name and is case sensitive, cannot contain whitespace, a plus (+) character, or begin with a period (.).
    # - The `version` is the package version.
    # - The purl subpath is used to represent a pods subspec (if present)
    #
    # Examples:
    #    pkg:cocoapods/AFNetworking@4.0.1
    #    pkg:cocoapods/MapsIndoors@3.24.0
    #    pkg:cocoapods/ShareKit@2.0#Twitter
    #    pkg:cocoapods/GoogleUtilities@7.5.2#NSData+zlib
    'cocoapods' => lambda { |purl|
                     if purl&.name&.match?(/\s|\+|\A\./)
                       raise InvalidPackageURL,
                             'name cannot contain whitespace, a plus (+) character, or begin with a period (.)'
                     end
                   },

    # `cargo` for Rust:
    #
    # - The default repository is `https://crates.io/`
    # - The `name` is the repository name.
    # - The `version` is the package version.
    #
    # Examples:
    #       pkg:cargo/rand@0.7.2
    #       pkg:cargo/clap@2.33.0
    #       pkg:cargo/structopt@0.3.11
    'cargo' => ->(purl) {},

    # `composer` for Composer PHP packages:
    #
    # - The default repository is `https://packagist.org`
    # - The `namespace` is the vendor.
    # - Note: private, local packages may have no name. In this case you cannot
    #   create a `purl` for these.
    #
    # - Examples:
    #    pkg:composer/laravel/laravel@5.5.0
    'composer' => ->(purl) {},

    # `conan` for Conan C/C++ packages. The purl is designed to closely resemble the Conan-native `<package-name>/<package-version>@<user>/<channel>` `syntax for package references <https://docs.conan.io/en/1.46/cheatsheet.html#package-terminology>`_.
    #
    # - `name`: The Conan `<package-name>`.
    # - `version`: The Conan `<package-version>`.
    # - `namespace`: The vendor of the package.
    # - Qualifier `user`: The Conan `<user>`. Only required if the Conan package was published with `<user>`.
    # - Qualifier `channel`: The Conan `<channel>`. Only required if the Conan package was published with Conan `<channel>`.
    # - Qualifier `rrev`: The Conan recipe revision (optional). If omitted, the purl refers to the latest recipe revision available for the given version.
    # - Qualifier `prev`: The Conan package revision (optional). If omitted, the purl refers to the latest package revision available for the given version and recipe revision.
    # - Qualifier `repository_url`: The Conan repository where the package is available (optional). If ommitted, `https://center.conan.io` as default repository is assumed.
    #
    # Additional qualifiers can be used to distinguish Conan packages with different settings or options, e.g. `os=Linux`, `build_type=Debug` or `shared=True`.
    #
    # If no additional qualifiers are used to distinguish Conan packages build with different settings or options, then the purl is ambiguous and it is up to the user to work out which package is being referred to (e.g. with context information).
    #
    # Examples::
    #    pkg:conan/openssl@3.0.3
    #    pkg:conan/openssl.org/openssl@3.0.3?user=bincrafters&channel=stable
    #    pkg:conan/openssl.org/openssl@3.0.3?arch=x86_64&build_type=Debug&compiler=Visual%20Studio&compiler.runtime=MDd&compiler.version=16&os=Windows&shared=True&rrev=93a82349c31917d2d674d22065c7a9ef9f380c8e&prev=b429db8a0e324114c25ec387bfd8281f330d7c5c
    'conan' => lambda { |purl|
                 if purl&.namespace.nil? != purl&.qualifiers&.fetch('channel').nil?
                   raise InvalidPackageURL, 'namespace and channel qualifiers must be used together'
                 end
               },

    # `conda` for Conda packages:
    #
    # - The default repository is `https://repo.anaconda.com`
    # - The `name` is the package name
    # - The `version` is the package version
    # - The qualifiers: `build` is the build string.
    #   `channel` is the package stored location.
    #   `subdir` is the associated platform.
    #   `type` is the package type.
    #
    # Examples:
    #       pkg:conda/absl-py@0.4.1?build=py36h06a4308_0&channel=main&subdir=linux-64&type=tar.bz2
    'conda' => ->(purl) {},

    # `cran` for CRAN R packages:
    #
    # - The default repository is `https://cran.r-project.org`
    # - The `name` is the package name and is case sensitive,
    #   but there cannot be two packages on CRAN
    #   with the same name ignoring case.
    # - The `version` is the package version.
    #
    # Examples:
    #       pkg:cran/A3@1.0.0
    #       pkg:cran/rJava@1.0-4
    #       pkg:cran/caret@6.0-88
    'cran' => lambda { |purl|
                raise InvalidPackageURL, 'version is required' if purl&.version.nil?
              },

    # `deb` for Debian, Debian derivatives, and Ubuntu packages:
    #
    #  - There is no default package repository:
    #    this should be implied either from the `distro` qualifiers key
    #    or using a base url as a `repository_url` qualifiers key
    #  - The `namespace` is the "vendor" name such as "debian" or "ubuntu".
    #    It is not case sensitive and must be lowercased.
    #  - The `name` is not case sensitive and must be lowercased.
    #  - The `version` is the version of the binary (or source) package.
    #  - `arch` is the qualifiers key for a package architecture.
    #    The special value `arch=source` identifies a Debian source package
    #    that usually consists of a Debian Source control file (.dsc)
    #    and corresponding upstream and Debian sources.
    #    The `dpkg-query` command can print the `name` and `version` of
    #    the corresponding source package of a binary package::
    #
    #       ```
    #       dpkg-query -f '${source:Package} ${source:Version}' -W <binary package name>
    #       ```
    #
    # Examples:
    #     pkg:deb/debian/curl@7.50.3-1?arch=i386&distro=jessie
    #     pkg:deb/debian/dpkg@1.19.0.4?arch=amd64&distro=stretch
    #     pkg:deb/ubuntu/dpkg@1.19.0.4?arch=amd64
    #     pkg:deb/debian/attr@1:2.4.47-2?arch=source
    #     pkg:deb/debian/attr@1:2.4.47-2%2Bb1?arch=amd64
    'deb' => lambda { |purl|
               purl&.namespace&.downcase!
               purl&.name&.downcase!
             },

    # `docker` for Docker images
    #
    # - The default repository is `https://hub.docker.com`
    # - The `namespace` is the registry/user/organization if present
    # - The version should be the image id sha256 or a tag.
    #   Since tags can be moved, a sha256 image id is preferred.
    #
    # Examples:
    #    pkg:docker/cassandra@latest
    #    pkg:docker/smartentry/debian@dc437cc87d10
    #    pkg:docker/customer/dockerimage@sha256%3A244fd47e07d10?repository_url=gcr.io
    'docker' => ->(purl) {},

    # `gem` for Rubygems:
    #
    # - The default repository is `https://rubygems.org`
    # - The `platform` qualifiers key is used to specify an alternative platform
    #   such as `java` for JRuby.
    #   The implied default is `ruby` for Ruby MRI.
    #
    # - Examples:
    #    pkg:gem/ruby-advisory-db-check@0.12.4
    #    pkg:gem/jruby-launcher@1.1.2?platform=java
    'gem' => ->(purl) {},

    # `generic` for plain, generic packages that do not fit anywhere else
    #  such as for "upstream-from-distro" packages.
    # In particular this is handy for a plain version control repository
    # such as a bare git repo.
    #
    # - There is no default repository.
    #   A `download_url` and `checksum` may be provided in `qualifiers`
    #   or as separate attributes outside of a `purl` for proper
    #   identification and location.
    # - When possible another or a new purl `type` should be used
    #   instead of using the `generic` type and eventually
    #   contributed back to this specification
    # - As for other `type`,
    #   the `name` component is mandatory.
    #   In the worst case it can be a file or directory name.
    #
    # Examples (truncated for brevity):
    #    pkg:generic/openssl@1.1.10g
    #    pkg:generic/openssl@1.1.10g?download_url=https://openssl.org/source/openssl-1.1.0g.tar.gz&checksum=sha256:de4d501267da
    #    pkg:generic/bitwarderl?vcs_url=git%2Bhttps://git.fsfe.org/dxtr/bitwarderl%40cc55108da32
    'generic' => ->(purl) {},

    # `github` for Github-based packages:
    # - The default repository is `https://github.com`
    # - The `namespace` is the user or organization.
    #   It is not case sensitive and must be lowercased.
    # - The `name` is the repository name.
    #   It is not case sensitive and must be lowercased.
    # - The `version` is a commit or tag
    #
    # Examples:
    #    pkg:github/package-url/purl-spec@244fd47e07d1004
    #    pkg:github/package-url/purl-spec@244fd47e07d1004#everybody/loves/dogs
    'github' => lambda { |purl|
                  purl&.namespace&.downcase!
                  purl&.name&.downcase!
                },

    # `golang` for Go packages
    #
    # - There is no default package repository:
    #   this is implied in the namespace using the `go get` command conventions
    # - The `namespace` and `name` must be lowercased.
    # - The `subpath` is used to point to a subpath inside a package
    # - The `version` is often empty when a commit is not specified and should be
    #   the commit in most cases when available.
    #
    # Examples:
    #    pkg:golang/github.com/gorilla/context@234fd47e07d1004f0aed9c
    #    pkg:golang/google.golang.org/genproto#googleapis/api/annotations
    #    pkg:golang/github.com/gorilla/context@234fd47e07d1004f0aed9c#api
    'golang' => lambda { |purl|
                  purl&.namespace&.downcase!
                  purl&.name&.downcase!
                },

    # `hackage` for Haskell packages
    #
    # - The default repository is `https://hackage.haskell.org`.
    # - The `version` is package version.
    # - The `name` is case sensitive and use kebab-case
    #
    # Examples:
    #    pkg:hackage/a50@0.5
    #    pkg:hackage/AC-HalfInteger@1.2.1
    #    pkg:hackage/3d-graphics-examples@0.0.0.2
    'hackage' => lambda { |purl|
                   raise InvalidPackageURL, 'name must be kebab-case' unless purl&.name =~ /^[a-z0-9-]+$/i
                 },

    # `hex` for Hex packages
    #
    # - The default repository is `https://repo.hex.pm`.
    # - The `namespace` is optional;
    #   it may be used to specify the organization for
    #   private packages on hex.pm.
    #   It is not case sensitive and must be lowercased.
    # - The `name` is not case sensitive and must be lowercased.
    #
    # Examples:
    #    pkg:hex/jason@1.1.2
    #    pkg:hex/acme/foo@2.3.
    #    pkg:hex/phoenix_html@2.13.3#priv/static/phoenix_html.js
    #    pkg:hex/bar@1.2.3?repository_url=https://myrepo.example.com
    'hex' => lambda { |purl|
               purl&.namespace&.downcase!
               purl&.name&.downcase!
             },

    # `maven` for Maven JARs and related artifacts
    #
    # - The default repository is `https://repo.maven.apache.org/maven2`
    # - The group id is the `namespace` and the artifact id is the `name`
    # - Known qualifiers keys are: `classifier` and `type`
    #   as defined in the POM documentation.
    #   Note that Maven uses a concept / coordinate called packaging
    #   which does not map directly 1:1 to a file extension.
    #   In this use case, we need to construct a link to
    #   one of many possible artifacts.
    #   Maven itself uses type in a dependency declaration
    #   when needed to disambiguate between them.
    #
    # Examples:
    #   pkg:maven/org.apache.xmlgraphics/batik-anim@1.9.1
    #   pkg:maven/org.apache.xmlgraphics/batik-anim@1.9.1?type=pom
    #   pkg:maven/org.apache.xmlgraphics/batik-anim@1.9.1?classifier=sources
    #   pkg:maven/org.apache.xmlgraphics/batik-anim@1.9.1?type=zip&classifier=dist
    #   pkg:maven/net.sf.jacob-projec/jacob@1.14.3?classifier=x86&type=dll
    #   pkg:maven/net.sf.jacob-projec/jacob@1.14.3?classifier=x64&type=dll
    'maven' => ->(purl) {},

    # `npm` for Node NPM packages:
    # - The default repository is `https://registry.npmjs.org`
    # - The `namespace` is used for the scope of a scoped NPM package.
    # - Per the package.json spec,
    #   new package "must not have uppercase letters in the name",
    #   therefore the must be lowercased.
    #
    # Examples:
    #    pkg:npm/foobar@12.3.1
    #    pkg:npm/%40angular/animation@12.3.1
    #    pkg:npm/mypackage@12.4.5?vcs_url=git://host.com/path/to/repo.git%404345abcd34343
    'npm' => lambda { |purl|
               purl&.name&.downcase!
             },

    # `nuget` for NuGet .NET packages:
    #
    # - The default repository is `https://www.nuget.org`
    # - There is no `namespace` per se even if the common convention is to use
    #   dot-separated package names where the first segment is `namespace`-like.
    #
    # Examples:
    #    pkg:nuget/EnterpriseLibrary.Common@6.0.1304
    'nuget' => lambda { |purl|
                 raise InvalidPackageURL, 'namespace is not allowed' if purl&.namespace
               },

    # `oci` for all artifacts stored in registries that conform to the
    # `OCI Distribution Specification <https://github.com/opencontainers/distribution-spec>`,
    # including container images built by Docker and others:
    #
    # - There is no canonical package repository for OCI artifacts.
    #   Therefore `oci` purls must be registry agnostic by default.
    #   To specify the repository, provide a `repository_url` value.
    # - OCI purls do not contain a `namespace`,
    #   although `repository_url` may contain a namespace
    #   as part of the physical location of the package.
    # - The `name` is not case sensitive and must be lowercased.
    #   The name is the last fragment of the repository name.
    #   For example if the repository name is `library/debian`
    #   then the `name` is `debian`.
    # - The `version` is the `sha256:hex_encoded_lowercase_digest`
    #   of the artifact
    #   and is required to uniquely identify the artifact.
    # - Optional qualifiers may include:
    #   - `arch`: key for a package architecture, when relevant
    #   - `repository_url`: A repository URL where the artifact may be found,
    #                       but not intended as the only location.
    #                       This value is encouraged to identify a
    #                       location the content may be fetched
    #   - `tag`: artifact tag that may have been associated with
    #            the digest at the time
    #
    # Examples:
    #    pkg:oci/debian@sha256%3A244fd47e07d10?repository_url=docker.io/library/debian&arch=amd64&tag=latest
    #    pkg:oci/debian@sha256%3A244fd47e07d10?repository_url=ghcr.io/debian&tag=bullseye
    #    pkg:oci/static@sha256%3A244fd47e07d10?repository_url=gcr.io/distroless/static&tag=latest
    #    pkg:oci/hello-wasm@sha256%3A244fd47e07d10?tag=v1
    'oci' => lambda { |purl|
               raise InvalidPackageURL, 'namespace is not allowed' if purl&.namespace

               purl&.name&.downcase!
             },

    # `pub` for Dart and Flutter packages:
    #
    # - The default repository is `https://pub.dartlang.org`
    # - Pub normalizes all package names to be lowercase and using underscores.
    #   The only allowed characters are `[a-z0-9_]`.
    # - More information on pub naming and versioning is available in the
    #   [pubspec documentation](https://dart.dev/tools/pub/pubspec)
    #
    # Examples:
    #   pkg:pub/characters@1.2.0
    #   pkg:pub/flutter@0.0.0
    'pub' => lambda { |purl|
               purl.name&.downcase!
               unless purl&.name =~ /^[a-z0-9_]+$/
                 raise InvalidPackageURL,
                       'name may only contain lowercase letters, digits, and underscores'
               end
             },

    # `pypi` for Python packages:
    #
    # - The default repository is `https://pypi.python.org`
    # - PyPi treats `-` and `_` as the same character and is not case sensitive.
    #   Therefore a Pypi package `name` must be lowercased and underscore `_`
    #   replaced with a dash `-`
    #
    # Examples:
    #    pkg:pypi/django@1.11.1
    #    pkg:pypi/django-allauth@12.23
    'pypi' => lambda { |purl|
                purl&.name&.downcase!
                purl&.name&.gsub!('_', '-')
              },

    # `rpm` for RPMs:
    #
    # - There is no default package repository:
    #   this should be implied either from the `distro` qualifiers key
    #   or using a repository base url as `repository_url` qualifiers key
    # - the `namespace` is the vendor such as `fedora` or `opensuse`
    #   It is not case sensitive and must be lowercased.
    # - the `name` is the RPM name and is case sensitive.
    # - the `version` is the combined version and release of an RPM
    # - `epoch` (optional for RPMs) is a qualifier
    #   as it's not required for unique identification,
    #   but when the epoch exists we strongly encourage using it
    # - `arch` is the qualifiers key for a package architecture
    #
    # Examples:
    #    pkg:rpm/fedora/curl@7.50.3-1.fc25?arch=i386&distro=fedora-25
    #    pkg:rpm/centerim@4.22.10-1.el6?arch=i686&epoch=1&distro=fedora-25
    'rpm' => lambda { |purl|
               purl&.namespace&.downcase!
             },

    # `swid` for ISO-IEC 19770-2 Software Identification (SWID) tags:
    #
    # - There is no default package repository.
    # - The `namespace` is the optional name and regid of the entity
    #   with a role of softwareCreator.
    #   If specified, name is required and is
    #   the first segment in the namespace.
    #   If regid is known,
    #   it must be specified as the second segment in the namespace.
    #   A maximum of two segments are supported.
    # - The `name` is the name
    #   as defined in the SWID `SoftwareIdentity` element
    # - The `version` is the version
    #   as defined in the SWID `SoftwareIdentity` element
    # - The qualifier `tag_id` must not be empty and corresponds to the tagId
    #   as defined in the SWID `SoftwareIdentity` element.
    #   Per the SWID specification, GUIDs are recommended.
    #   If a GUID is used, it must be lowercase.
    #   If a GUID is not used,
    #   the tag_id qualifier is case aware but not case sensitive
    # - The qualifier `tag_version` is an optional integer
    #   and corresponds to the tagVersion
    #   as defined in the SWID `SoftwareIdentity` element.
    #   If not specified, defaults to 0
    # - The qualifier `patch` is optional and corresponds to the patch
    #   as defined in the SWID `SoftwareIdentity` element.
    #   If not specified, defaults to false
    # - The qualifier `tag_creator_name` is optional.
    #   If the tag creator is different from the software creator,
    #   the `tag_creator_name` qualifier should be specified
    # - The qualifier `tag_creator_regid` is optional.
    #   If the tag creator is different from the software creator,
    #   the `tag_creator_regid` qualifier should be specified
    #
    # Use of known `qualifiers` key/value pairs such as `download_url`
    # can be used to specify where the package was retrieved from.
    #
    # Examples:
    #    pkg:swid/Acme/example.com/Enterprise+Server@1.0.0?tag_id=75b8c285-fa7b-485b-b199-4745e3004d0d
    #    pkg:swid/Fedora@29?tag_id=org.fedoraproject.Fedora-29
    #    pkg:swid/Adobe+Systems+Incorporated/Adobe+InDesign@CC?tag_id=CreativeCloud-CS6-Win-GM-MUL
    'swid' => lambda { |purl|
                if purl&.namespace&.split('/')&.length > 2
                  raise InvalidPackageURL,
                        'namespace may have at most two path components'
                end
              },

    # `swift` for Swift packages:
    # - There is no default package repository:
    #   this should be implied from `namespace`
    # - The `namespace` is source host and user/organization and is required.
    # - The `name` is the repository name.
    # - The `version` is the package version and is required.
    #
    # Examples:
    #    pkg:swift/github.com/Alamofire/Alamofire@5.4.3
    #    pkg:swift/github.com/RxSwiftCommunity/RxFlow@2.12.4
    'swift' => lambda { |purl|
                 raise InvalidPackageURL, 'namespace is required' if purl&.namespace.nil?
                 raise InvalidPackageURL, 'version is required' if purl&.version.nil?
               }
  }

  private

  def encode(string)
    URI.encode_www_form_component(string).gsub('+', '%20').gsub('%3A', ':').gsub('%2F', '/')
  end
end
