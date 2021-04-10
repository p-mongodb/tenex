
class CannotDetermineProject < StandardError
end

ProjectConfig = Struct.new(
  :gh_upstream_owner_name,
  :gh_repo_name,
  :jira_project,
  :eg_project_name,
)

PROJECT_CONFIGS = {
  'mongo-ruby-driver' => ProjectConfig.new(
    'mongodb',
    'mongo-ruby-driver',
    'RUBY',
    'mongo-ruby-driver',
  ),
  'mongoid' => ProjectConfig.new(
    'mongodb',
    'mongoid',
    'MONGOID',
    'mongoid',
  ),
  'mongoid-7.2' => ProjectConfig.new(
    'mongodb',
    'mongoid',
    'MONGOID',
    'mongoid-7.2',
  ),
  'mongoid-7.1' => ProjectConfig.new(
    'mongodb',
    'mongoid',
    'MONGOID',
    'mongoid-7.1',
  ),
  'mongoid-7.0' => ProjectConfig.new(
    'mongodb',
    'mongoid',
    'MONGOID',
    'mongoid-7.0',
  ),
  'bson-ruby' => ProjectConfig.new(
    'mongodb',
    'bson-ruby',
    'RUBY',
    'bson-ruby',
  ),
  'mongo-ruby-kerberos' => ProjectConfig.new(
    'mongodb',
    'mongo-ruby-kerberos',
    'RUBY',
    'mongo-ruby-kerberos',
  ),
  'specifications' => ProjectConfig.new(
    'mongodb',
    'specifications',
    'DRIVERS',
    nil,
  ),
  'writing' => ProjectConfig.new(
    'mongodb',
    'specifications',
    'WRITING',
    nil,
  ),
  'mongo-ruby-toolchain' => ProjectConfig.new(
    '10gen',
    'mongo-ruby-toolchain',
    'RUBY',
    'mongo-ruby-driver-toolchain',
  ),
  'libmongocrypt' => ProjectConfig.new(
    'mongodb',
    'libmongocrypt',
    'MONGOCRYPT',
    nil,
  ),
  'cloud-docs' => ProjectConfig.new(
    '10gen',
    'cloud-docs',
    'DOCSP',
    nil,
  ),
  'astrolabe' => ProjectConfig.new(
    'mongodb-labs',
    'drivers-atlas-testing',
    nil,
    'drivers-atlas-testing',
  ),
}

class ProjectDetector
  def initialize(path = nil)
    path ||= Dir.pwd

    until @repo_name || %w(. /).include?(path)
      case basename = File.basename(path)
      when 'mongoid', 'specifications', 'bson-ruby', 'libmongocrypt'
        key = basename
        break
      when 'ruby-driver'
        key = 'mongo-ruby-driver'
        break
      when 'krb'
        key = 'mongo-ruby-kerberos'
        break
      when 'toolchain'
        key = 'mongo-ruby-toolchain'
        break
      when 'cloud-docs'
        key = 'cloud-docs'
        break
      when 'astrolabe'
        key = 'astrolabe'
        break
      when 'source'
        if File.basename(File.dirname(path)) == 'specifications'
          key = 'specifications'
          break
        end
      end
      path = File.dirname(path)
    end

    @project_config = PROJECT_CONFIGS[key]

    if project_config.nil?
      raise CannotDetermineProject, "Cannot figure out the project"
    end
  end

  attr_reader :project_config
end

class EgProjectResolver
  def initialize(eg_project_name)
    @project_config = PROJECT_CONFIGS.detect do |key, config|
      config.eg_project_name == eg_project_name
    end.last
  end

  attr_reader :project_config
end
