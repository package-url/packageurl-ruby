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

    test_suite = JSON.parse(File.read('spec/fixtures/test-suite-data.json'))
    test_suite.each do |test|
      context "with #{test['description']}", url: test['purl'] do
        it {
          should have_attributes type: test['type'],
                                 namespace: test['namespace'],
                                 name: test['name'],
                                 version: test['version'],
                                 qualifiers: test['qualifiers'],
                                 subpath: test['subpath']
        }

        it { should have_description test['canonical_purl'] }
      end
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
