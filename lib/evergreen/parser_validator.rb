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
      begin
        doc = YAML.load(project_file_contents)
      rescue Psych::SyntaxError => e
        @errors = ["Failed to parse project file: #{e.class}: #{e}"]
        return
      end

      errors = []

      doc['tasks'].each do |task|
        if task['commands']
          task['commands'].each do |command|
            if command['func']
              unless doc['functions']
                errors << %Q`Task "#{task['name']}" references undefined function "#{command['func']}" - there are no functions defined`
                next
              end

              unless doc['functions'].key?(command['func'])
                errors << %Q`Task "#{task['name']}" references undefined function "#{command['func']}"`
              end
            end
          end
        end
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
        msg = "The following errors were detected in project file:\n#{errors.join("\n")}"
        raise ProjectFileInvalid, msg
      end
    end
  end
end
