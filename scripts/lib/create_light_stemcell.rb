require 'yaml'
require 'tmpdir'
require 'open3'
require 'digest/sha1'

class LightStemcellCreator
  class Error < StandardError; end

  def self.run(version, os, image_id, output_directory)
    raise Error, "Output directory '#{output_directory}' does not exist" unless File.exists?(output_directory)
    filename = "light-bosh-stemcell-#{version}-openstack-kvm-#{os}-go_agent.tgz"
    output_path = File.absolute_path(File.join(output_directory, filename))

    Dir.mktmpdir do |tmp_dir|
      Dir.chdir(tmp_dir) do
        File.write('image', '')
        sha1 = Digest::SHA1.hexdigest(File.read('image')).force_encoding('utf-8')

        manifest = {
          'name' => "bosh-openstack-kvm-#{os}-go_agent",
          'version' => version,
          'bosh_protocol' => 1,
          'sha1' => sha1,
          'operating_system' => os,
          'stemcell_formats' => ['openstack-light'],
          'cloud_properties' => {
            'name' => "bosh-openstack-kvm-#{os}-go_agent",
            'version' => version,
            'infrastructure' => 'openstack',
            'hypervisor' => 'kvm',
            'disk' => 3072,
            'disk_format' => 'qcow2',
            'container_format' => 'bare',
            'os_type' => 'linux',
            'os_distro' => extract_distro(os),
            'architecture' => 'x86_64',
            'auto_disk_config' => true,
            'image_id' => image_id
          }
        }
        File.write('stemcell.MF', YAML.dump(manifest))

        output, status = Open3.capture2e("tar czf #{output_path} stemcell.MF image")
        raise Error, output if status.exitstatus != 0
      end
      output_path
    end
  end

  private

  def self.extract_distro(os)
    distro = os.rpartition('-').first
    if distro.empty?
      raise Error, "OS name '#{os}' contains no dash to separate the version from the name, i.e. 'name-version'"
    end
    distro
  end
end
