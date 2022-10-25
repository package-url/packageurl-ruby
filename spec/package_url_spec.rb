# frozen_string_literal: true

RSpec.describe PackageURL do
  it 'has a version number' do
    expect(PackageURL::VERSION).not_to be nil
  end

  describe '#initialize' do
    it 'should raise an error if no argument is passed' do
      expect { PackageURL.new }.to raise_error(ArgumentError)
    end

    it 'should raise an error if type parameter is missing' do
      expect do
        PackageURL.new type: nil,
                       name: 'test'
      end.to raise_error(ArgumentError)
    end

    it 'should raise an error if name parameter is missing' do
      expect do
        PackageURL.new type: 'example',
                       name: nil
      end.to raise_error(ArgumentError)
    end

    it 'should construct package URL with provided components' do
      components = {
        type: 'example',
        namespace: 'test',
        name: 'test',
        version: '1.0.0',
        qualifiers: { 'arch' => 'x86_64' },
        subpath: 'path/to/package'
      }

      purl = PackageURL.new(**components)

      expect(purl).to have_attributes(**components)
    end

    context 'normalization' do
      it 'should lowercase provided type component' do
        purl = PackageURL.new(type: 'EXAMPLE', name: 'test')

        expect(purl.type).to eq('example')
        expect(purl.name).to eq('test')
      end

      it 'should not lowercase provided name component' do
        purl = PackageURL.new(type: 'example', name: 'TEST')

        expect(purl.type).to eq('example')
        expect(purl.name).to eq('TEST')
      end
    end
  end

  describe '#parse' do
    it 'should raise an error if no argument is passed' do
      expect { PackageURL.parse }.to raise_error(ArgumentError)
    end

    it 'should raise an error if an invalid package URL string is passed' do
      expect { PackageURL.parse('invalid') }.to raise_error(PackageURL::InvalidPackageURL)
    end

    subject { |example| PackageURL.parse(example.metadata[:url]) }

    # These tests were translated from the test suite data file provided at
    # https://github.com/package-url/purl-spec/blob/0b1559f76b79829e789c4f20e6d832c7314762c5/README.rst#some-purl-examples.

    context 'with valid RubyGems package URL', url: 'pkg:gem/ruby-advisory-db-check@0.12.4' do
      it {
        should have_attributes type: 'gem',
                               namespace: nil,
                               name: 'ruby-advisory-db-check',
                               version: '0.12.4',
                               qualifiers: nil,
                               subpath: nil
      }

      it { should have_description 'pkg:gem/ruby-advisory-db-check@0.12.4' }
    end

    context 'with valid BitBucket package URL', url: 'pkg:bitbucket/birkenfeld/pygments-main@244fd47e07d1014f0aed9c' do
      it {
        should have_attributes type: 'bitbucket',
                               namespace: 'birkenfeld',
                               name: 'pygments-main',
                               version: '244fd47e07d1014f0aed9c',
                               qualifiers: nil,
                               subpath: nil
      }

      it { should have_description 'pkg:bitbucket/birkenfeld/pygments-main@244fd47e07d1014f0aed9c' }
    end

    context 'with valid GitHub package URL', url: 'pkg:github/package-url/purl-spec@244fd47e07d1004f0aed9c' do
      it {
        should have_attributes type: 'github',
                               namespace: 'package-url',
                               name: 'purl-spec',
                               version: '244fd47e07d1004f0aed9c',
                               qualifiers: nil,
                               subpath: nil
      }

      it { should have_description 'pkg:github/package-url/purl-spec@244fd47e07d1004f0aed9c' }
    end

    context 'with valid Go module URL', url: 'pkg:golang/google.golang.org/genproto#googleapis/api/annotations' do
      it {
        should have_attributes type: 'golang',
                               namespace: 'google.golang.org',
                               name: 'genproto',
                               version: nil,
                               qualifiers: nil,
                               subpath: 'googleapis/api/annotations'
      }

      it { should have_description 'pkg:golang/google.golang.org/genproto#googleapis/api/annotations' }
    end

    context 'with valid Maven package URL', url: 'pkg:maven/org.apache.commons/io@1.3.4' do
      it {
        should have_attributes type: 'maven',
                               namespace: 'org.apache.commons',
                               name: 'io',
                               version: '1.3.4',
                               qualifiers: nil,
                               subpath: nil
      }

      it { should have_description 'pkg:maven/org.apache.commons/io@1.3.4' }
    end

    context 'with valid NPM package URL', url: 'pkg:npm/foobar@12.3.1' do
      it {
        should have_attributes type: 'npm',
                               namespace: nil,
                               name: 'foobar',
                               version: '12.3.1',
                               qualifiers: nil,
                               subpath: nil
      }

      it { should have_description 'pkg:npm/foobar@12.3.1' }
    end

    context 'with valid NuGet package URL', url: 'pkg:nuget/EnterpriseLibrary.Common@6.0.1304' do
      it {
        should have_attributes type: 'nuget',
                               namespace: nil,
                               name: 'EnterpriseLibrary.Common',
                               version: '6.0.1304',
                               qualifiers: nil,
                               subpath: nil
      }

      it { should have_description 'pkg:nuget/EnterpriseLibrary.Common@6.0.1304' }
    end

    context 'with valid PyPI package URL', url: 'pkg:pypi/django@1.11.1' do
      it {
        should have_attributes type: 'pypi',
                               namespace: nil,
                               name: 'django',
                               version: '1.11.1',
                               qualifiers: nil,
                               subpath: nil
      }

      it { should have_description 'pkg:pypi/django@1.11.1' }
    end

    context 'with valid RPM package URL', url: 'pkg:rpm/fedora/curl@7.50.3-1.fc25?arch=i386&distro=fedora-25' do
      it {
        should have_attributes type: 'rpm',
                               namespace: 'fedora',
                               name: 'curl',
                               version: '7.50.3-1.fc25',
                               qualifiers: { 'arch' => 'i386',
                                             'distro' => 'fedora-25' },
                               subpath: nil
      }

      it { should have_description 'pkg:rpm/fedora/curl@7.50.3-1.fc25?arch=i386&distro=fedora-25' }
    end

    context 'with URL encoded subpath', url: 'pkg:golang/google.golang.org/genproto#googleapis%20api%20annotations' do
      it {
        should have_attributes type: 'golang',
                               namespace: 'google.golang.org',
                               name: 'genproto',
                               version: nil,
                               qualifiers: nil,
                               subpath: 'googleapis api annotations'
      }

      it { should have_description 'pkg:golang/google.golang.org/genproto#googleapis+api+annotations' }
    end


    context 'when namespace or subpath contains empty segments', url: 'pkg:golang/google.golang.org//.././genproto#googleapis/..//./api/annotations' do
      it {
        should have_attributes type: 'golang',
                               namespace: 'google.golang.org/../.',
                               name: 'genproto',
                               version: nil,
                               qualifiers: nil,
                               subpath: 'googleapis/api/annotations'
      }

      it { should have_description 'pkg:golang/google.golang.org/.././genproto#googleapis/api/annotations' }
    end

    context 'when qualifiers have no value', url: 'pkg:rpm/fedora/curl@7.50.3-1.fc25?arch=i386&distro=fedora-25&foo=&bar=' do
      it {
        should have_attributes type: 'rpm',
                               namespace: 'fedora',
                               name: 'curl',
                               version: '7.50.3-1.fc25',
                               qualifiers: { 'arch' => 'i386',
                                             'distro' => 'fedora-25' },
                               subpath: nil
      }

      it { should have_description 'pkg:rpm/fedora/curl@7.50.3-1.fc25?arch=i386&distro=fedora-25' }
    end
  end

  describe 'pattern matching' do
    subject { PackageURL.new(type: 'example', name: 'test') }

    it 'should support hash destructuring' do
      case subject
      in type: String => type, name: String => name
        expect(type).to eq('example')
        expect(name).to eq('test')
      else
        raise 'should have matched'
      end
    end

    it 'should support array destructuring' do
      case subject
      in ['pkg', String => type, nil, String => name, *]
        expect(type).to eq('example')
        expect(name).to eq('test')
      else
        raise 'should have matched'
      end
    end
  end
end
