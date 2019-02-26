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
end
