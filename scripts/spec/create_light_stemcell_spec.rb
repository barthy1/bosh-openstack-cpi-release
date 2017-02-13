require_relative '../lib/create_light_stemcell'
require 'open3'
require 'tmpdir'
require 'pathname'

describe LightStemcellCreator do
  describe '.run' do
    let(:version) { '3263.8' }
    let(:os) { 'ubuntu-trusty' }
    let(:image_id) { '66ad0633-3a4c-48b1-8532-1b31aa94334b'}
    let(:output_directory) { Dir.mktmpdir }
    let(:actual_output_directory) { output_directory }

    let(:expected_name) { "bosh-openstack-kvm-#{os}-go_agent" }
    let(:expected_filename) { "light-bosh-stemcell-#{version}-openstack-kvm-#{os}-go_agent.tgz" }

    after(:each) do
      FileUtils.rm_r(output_directory)
    end

    context 'executes successfully' do
      before do
        @filename = LightStemcellCreator.run(version, os, image_id, actual_output_directory)
      end

      context 'with absolute path' do
        it 'creates file' do
          expect(File.exist?(File.join(actual_output_directory, expected_filename))).to be(true)
        end
      end

      context 'with relative path' do
        let(:actual_output_directory) { Pathname.new(output_directory).relative_path_from(Pathname.pwd)}

        it 'creates file' do
          expect(File.exist?(File.join(actual_output_directory, expected_filename))).to be(true)
        end
      end

      it 'returns file name' do
        expect(@filename).to eq(File.join(actual_output_directory, expected_filename))
      end

      describe 'creates tarball' do
        let(:manifest_file) { File.join(actual_output_directory, 'stemcell.MF') }

        before do
          output, status = Open3.capture2e("tar xzf #{File.join(actual_output_directory, expected_filename)} -C #{actual_output_directory}")
          raise output if status.exitstatus != 0
        end

        it 'does not contain files starting with `./`' do
          expect(`tar tf #{File.join(actual_output_directory, expected_filename)}`.lines).to_not include( start_with('./'))
        end

        it 'contains empty image file' do
          image_file = File.join(actual_output_directory, 'image')
          expect(File.exist?(image_file)).to be(true)
          expect(File.size(image_file)).to eq(0)
        end

        it 'contains a manifest file' do
          expect(File.exist?(manifest_file)).to be(true)
        end

        it 'contains manifest with valid content' do
          expected_content = <<EOT
---
name: bosh-openstack-kvm-ubuntu-trusty-go_agent
version: '3263.8'
bosh_protocol: 1
sha1: da39a3ee5e6b4b0d3255bfef95601890afd80709
operating_system: ubuntu-trusty
stemcell_formats:
- openstack-qcow2
cloud_properties:
  name: bosh-openstack-kvm-ubuntu-trusty-go_agent
  version: '3263.8'
  infrastructure: openstack
  hypervisor: kvm
  disk: 3072
  disk_format: qcow2
  container_format: bare
  os_type: linux
  os_distro: ubuntu
  architecture: x86_64
  auto_disk_config: true
  image_id: 66ad0633-3a4c-48b1-8532-1b31aa94334b
EOT
          expect(File.read(manifest_file)).to eq(expected_content)
        end

        context 'with specified version' do
          let(:version) { 'my-version' }

          it 'writes version to manifest' do
            expect(YAML.load_file(manifest_file)['version']).to eq(version)
          end

          it 'writes version to cloud properties in manifest' do
            expect(YAML.load_file(manifest_file)['cloud_properties']['version']).to eq(version)
          end
        end

        context 'with specified os' do
          let(:os) { 'my-os-version' }

          it 'writes os to manifest' do
            expect(YAML.load_file(manifest_file)['operating_system']).to eq('my-os-version')
          end

          it 'writes os distro to manifest considering the part after the last dash as version' do
            expect(YAML.load_file(manifest_file)['cloud_properties']['os_distro']).to eq('my-os')
          end

          it 'writes name to manifest' do
            expect(YAML.load_file(manifest_file)['name']).to eq(expected_name)
          end

          it 'writes name to cloud properties in manifest' do
            expect(YAML.load_file(manifest_file)['cloud_properties']['name']).to eq(expected_name)
          end
        end

        context 'with heavy stemcell image id specified' do
          let(:image_id) { 'my-image-id' }

          it 'writes image id' do
            expect(YAML.load_file(manifest_file)['cloud_properties']['image_id']).to eq(image_id)
          end
        end
      end

    end

    context 'when an error occurs' do
      context 'when output directory does not exist' do
        it 'raises an error' do
          non_existing_directory = File.join(actual_output_directory, 'non-existing-dir')

          expect{
            LightStemcellCreator.run(version, os, image_id, non_existing_directory)
          }.to raise_error LightStemcellCreator::Error, "Output directory '#{non_existing_directory}' does not exist"
        end
      end

      context 'when tar raises an error' do
        it 'reports this error' do
          allow(Open3).to receive(:capture2e).and_return(['error text', double('status', exitstatus: 1)])

          expect{
            LightStemcellCreator.run(version, os, image_id, actual_output_directory)
          }.to raise_error LightStemcellCreator::Error, 'error text'
        end
      end

      context 'when os parameter does not contain a `-`' do
        let(:os) { 'name_only' }

        it 'raises an error' do
          expect{
            LightStemcellCreator.run(version, os, image_id, actual_output_directory)
          }.to raise_error LightStemcellCreator::Error, "OS name 'name_only' contains no dash to separate the version from the name, i.e. 'name-version'"
        end
      end
    end


  end
end