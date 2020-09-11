module Mappings
  class MappingMissing < StandardError; end

  module_function def repo_path_to_jira_project(path)
    if defined?(Pathname) && path.is_a?(Pathname)
      path = path.to_s
    end
    case path
    when /mongoid/
      'mongoid'
    when /specifications/
      'spec'
    when /\bruby(-driver)?\b/
      'ruby'
    else
      raise MappingMissing, "No mapping for #{path}"
    end.upcase
  end

  module_function def repo_full_name_to_jira_project(repo_full_name)
    case repo_full_name
    when 'mongodb/mongoid'
      'mongoid'
    when 'mongodb/mongo-ruby-driver', 'mongodb/bson-ruby', 'mongodb/mongo-ruby-kerberos'
      'ruby'
    when 'mongodb/specifications'
      'spec'
    when '10gen/mongo-ruby-toolchain'
      'ruby'
    when 'mongodb-labs/drivers-atlas-testing'
      'drivers-atlas-testing'
    else
      raise "Bogus repo name: #{repo_full_name}"
    end.upcase
  end
end
