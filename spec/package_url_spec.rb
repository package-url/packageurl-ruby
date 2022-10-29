# frozen_string_literal: true

RSpec.shared_context 'with purl matrix' do
  where do
    {
      'valid RubyGems package URL' => {
        url: 'pkg:gem/ruby-advisory-db-check@0.12.4',
        type: 'gem',
        namespace: nil,
        name: 'ruby-advisory-db-check',
        version: '0.12.4',
        qualifiers: nil,
        subpath: nil
      },
      'valid BitBucket package URL' => {
        url: 'pkg:bitbucket/birkenfeld/pygments-main@244fd47e07d1014f0aed9c',
        type: 'bitbucket',
        namespace: 'birkenfeld',
        name: 'pygments-main',
        version: '244fd47e07d1014f0aed9c',
        qualifiers: nil,
        subpath: nil
      },
      'valid GitHub package URL' => {
        url: 'pkg:github/package-url/purl-spec@244fd47e07d1004f0aed9c',
        type: 'github',
        namespace: 'package-url',
        name: 'purl-spec',
        version: '244fd47e07d1004f0aed9c',
        qualifiers: nil,
        subpath: nil
      },
      'valid Go module URL' => {
        url: 'pkg:golang/google.golang.org/genproto#googleapis/api/annotations',
        type: 'golang',
        namespace: 'google.golang.org',
        name: 'genproto',
        version: nil,
        qualifiers: nil,
        subpath: 'googleapis/api/annotations'
      },
      'valid Maven package URL' => {
        url: 'pkg:maven/org.apache.commons/io@1.3.4',
        type: 'maven',
        namespace: 'org.apache.commons',
        name: 'io',
        version: '1.3.4',
        qualifiers: nil,
        subpath: nil
      },
      'valid NPM package URL' => {
        url: 'pkg:npm/foobar@12.3.1',
        type: 'npm',
        namespace: nil,
        name: 'foobar',
        version: '12.3.1',
        qualifiers: nil,
        subpath: nil
      },
      'valid NuGet package URL' => {
        url: 'pkg:nuget/EnterpriseLibrary.Common@6.0.1304',
        type: 'nuget',
        namespace: nil,
        name: 'EnterpriseLibrary.Common',
        version: '6.0.1304',
        qualifiers: nil,
        subpath: nil
      },
      'valid PyPI package URL' => {
        url: 'pkg:pypi/django@1.11.1',
        type: 'pypi',
        namespace: nil,
        name: 'django',
        version: '1.11.1',
        qualifiers: nil,
        subpath: nil
      },
      'valid RPM package URL' => {
        url: 'pkg:rpm/fedora/curl@7.50.3-1.fc25?arch=i386&distro=fedora-25',
        type: 'rpm',
        namespace: 'fedora',
        name: 'curl',
        version: '7.50.3-1.fc25',
        qualifiers: { 'arch' => 'i386', 'distro' => 'fedora-25' },
        subpath: nil
      },
      'package URL with checksums' => {
        url: 'pkg:rpm/name?checksums=a,b,c',
        type: 'rpm',
        namespace: nil,
        name: 'name',
        version: nil,
        qualifiers: { 'checksums' => %w[a b c] },
        subpath: nil
      }
    }
  end
end

RSpec.describe PackageURL do
  describe '#initialize' do
    let(:args) do
      {
        type: 'example',
        namespace: 'test',
        name: 'test',
        version: '1.0.0',
        qualifiers: { 'arch' => 'x86_64' },
        subpath: 'path/to/package'
      }
    end

    subject { described_class.new(**args) }

    context 'with well-formed arguments' do
      it { is_expected.to have_attributes(**args) }
    end

    context 'when no arguments are given' do
      it { expect { described_class.new }.to raise_error(ArgumentError) }
    end

    context 'when required parameters are missing' do
      where(:param) { %i[type name] }

      before do
        args[param] = nil
      end

      with_them do
        it { expect { subject }.to raise_error(ArgumentError) }
      end
    end

    describe 'normalization' do
      it 'downcases provided type component' do
        purl = described_class.new(type: 'EXAMPLE', name: 'test')

        expect(purl.type).to eq('example')
        expect(purl.name).to eq('test')
      end

      it 'does not down provided name component' do
        purl = described_class.new(type: 'example', name: 'TEST')

        expect(purl.type).to eq('example')
        expect(purl.name).to eq('TEST')
      end
    end
  end

  describe '#parse' do
    subject(:purl) { described_class.parse(url) }

    include_context 'with purl matrix'

    with_them do
      it do
        is_expected.to have_attributes(
          type: type,
          namespace: namespace,
          name: name,
          version: version,
          qualifiers: qualifiers,
          subpath: subpath
        )
      end
    end

    it 'raises an error if no argument is passed' do
      expect { described_class.parse }.to raise_error(ArgumentError)
    end

    it 'raises an error if an invalid package URL string is passed' do
      expect { described_class.parse('invalid') }.to raise_error(described_class::InvalidPackageURL)
    end

    context 'when namespace or subpath contains an encoded slash' do
      where(:url) do
        [
          'pkg:golang/google.org/golang/genproto#googleapis%2fapi%2fannotations',
          'pkg:golang/google.org%2fgolang/genproto#googleapis/api/annotations'
        ]
      end

      with_them do
        xit { expect { purl }.to raise_error(described_class::InvalidPackageURL) }
      end
    end

    context 'when name contains an encoded slash' do
      let(:url) { 'pkg:golang/google.org/golang%2fgenproto#googleapis/api/annotations' }

      it do
        is_expected.to have_attributes(
          type: 'golang',
          namespace: 'google.org',
          name: 'golang/genproto',
          version: nil,
          qualifiers: nil,
          subpath: 'googleapis/api/annotations'
        )
      end
    end

    context 'with URL encoded segments' do
      let(:url) do
        'pkg:golang/namespace%21/google.golang.org%20genproto@version%21?k=v%21#googleapis%20api%20annotations'
      end

      xit 'decodes them' do
        is_expected.to have_attributes(
          type: 'golang',
          namespace: 'namespace!',
          name: 'google.golang.org genproto',
          version: 'version!',
          qualifiers: { 'k' => 'v!' },
          subpath: 'googleapis api annotations'
        )
      end
    end

    context 'when segments contain empty values' do
      let(:url) { 'pkg:golang/google.golang.org//.././genproto#googleapis/..//./api/annotations' }

      xit 'removes them from the segments' do
        is_expected.to have_attributes(
          type: 'golang',
          namespace: 'google.golang.org/../.', # . and .. are allowed in the namespace, but not the subpath
          name: 'genproto',
          version: nil,
          qualifiers: nil,
          subpath: 'googleapis/api/annotations'
        )
      end
    end

    context 'when qualifiers have no value' do
      let(:url) { 'pkg:rpm/fedora/curl@7.50.3-1.fc25?arch=i386&distro=fedora-25&foo=&bar=' }

      it 'they are ignored' do
        is_expected.to have_attributes(
          type: 'rpm',
          namespace: 'fedora',
          name: 'curl',
          version: '7.50.3-1.fc25',
          qualifiers: { 'arch' => 'i386',
                        'distro' => 'fedora-25' },
          subpath: nil
        )
      end
    end
  end

  describe '#to_h' do
    let(:purl) do
      described_class.new(
        type: type,
        namespace: namespace,
        name: name,
        version: version,
        qualifiers: qualifiers,
        subpath: subpath
      )
    end

    subject(:to_h) { purl.to_h }

    include_context 'with purl matrix'

    with_them do
      it do
        is_expected.to eq(
          {
            scheme: 'pkg',
            type: type,
            namespace: namespace,
            name: name,
            version: version,
            qualifiers: qualifiers,
            subpath: subpath
          }
        )
      end
    end
  end

  describe '#to_s' do
    let(:purl) do
      described_class.new(
        type: type,
        namespace: namespace,
        name: name,
        version: version,
        qualifiers: qualifiers,
        subpath: subpath
      )
    end

    subject(:to_s) { purl.to_s }

    include_context 'with purl matrix'

    with_them do
      it { is_expected.to eq(url) }
    end
  end
end
