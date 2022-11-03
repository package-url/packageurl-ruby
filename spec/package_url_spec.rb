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
  end

  describe '#parse' do
    it 'should raise an error if no argument is passed' do
      expect { PackageURL.parse }.to raise_error(ArgumentError)
    end

    test_suite = JSON.parse(File.read('spec/fixtures/test-suite-data.json'))
    test_suite.each do |test|
      context "with #{test['description']} (`#{test['purl']}`)" do
        subject { -> { PackageURL.parse(test['purl']) } }

        if test['is_invalid']
          it 'should raise an error' do
            should raise_error(PackageURL::InvalidPackageURL)
          end
        else
          it 'should match expected attributes' do
            expect(subject.call).to have_attributes type: test['type'],
                                                    namespace: test['namespace'],
                                                    name: test['name'],
                                                    version: test['version'],
                                                    qualifiers: test['qualifiers'],
                                                    subpath: test['subpath']
            expect(subject.call.to_s).to eq(test['canonical_purl'])
          end
        end
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
