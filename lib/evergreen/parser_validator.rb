autoload :YAML, 'yaml'

module Evergreen
  class ProjectFileInvalid < StandardError
  end

  class ParserValidator
    def initialize(project_file_contents)
      @project_file_contents = project_file_contents
    end

    attr_reader :project_file_contents

    def validate
      errors = []
      begin
        doc = YAML.load(project_file_contents)
      rescue Psych::SyntaxError => e
        errors << e
      end

      @errors = errors
    end

    def errors
      if @errors.nil?
        validate
      end
      @errors
    end

    def validate!
      if errors.any?
        msg = errors.map { |error| "#{error.class}: #{error}" }.join("\n")
        msg = "The following errors were detected in project file:\n#{msg}"
        raise ProjectFileInvalid, msg
      end
    end
  end
end
