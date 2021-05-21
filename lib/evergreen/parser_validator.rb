autoload :YAML, 'yaml'

module Evergreen
  class ProjectFileInvalid < StandardError
  end

  class ParserValidator
    def initialize(project_file_contents, **opts)
      @project_file_contents = project_file_contents
      @options = {use_service: true}.update(opts).freeze
    end

    attr_reader :project_file_contents
    attr_reader :options

    def validate
      begin
        doc = YAML.load(project_file_contents)
      rescue Psych::SyntaxError => e
        @errors = ["Failed to parse project file: #{e.class}: #{e}"]
        return
      end

      errors = []

      doc['tasks']&.each do |task|
        if task['name'].include?(' ')
          # Spaces in task names are not expilcitly prohibited, but, per
          # the Evergreen team, Evergreen's handling of task names with spaces
          # is "poor" which causes unspecified issues.
          # This validator flags spaces in task names as an error.
          errors << %Q`Task #{task['name']} contains a space in its name. Evergreen does not explicitly prohibit this but it mishandles tasks with spaces in their names`
        end

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

      doc['functions']&.each do |name, function|
        unless function.is_a?(Array)
          errors << %Q`Function "#{name}" contains data of wrong type: expected Array, found #{function.class}. A function is expected to contain a list of commands to be run.`
        end
        function.each_with_index do |command, index|
          unless command.is_a?(Hash)
            errors << %Q`Function "#{name}" command #{index+1} contains data of wrong type: expected Hash, found #{command.class}: #{command}`
            next
          end
          unless command['command']
            errors << %Q`Function "#{name}" command #{index+1} does not have the "command" key:\n#{command.to_yaml}`
          end
        end
      end

      axes = {}
      doc['axes']&.each do |axis|
        values = axis['values']
        if values.nil?
          errors << %Q`Axis #{axis['id']} does not have any values`
          next
        end
        values.each_with_index do |value, index|
          # `id: no` is interpreted by YAML to mean `id: false`
          unless value.key?('id')
            errors << %Q`Axis #{axis['id']} value #{index+1} does not have an id: #{value.inspect}`
          end
          # It's ok to not have variables.
          #unless vars = value['variables']
          #  errors << %Q`Axis #{axis['id']} value #{index+1} has no variables: #{value.inspect}`
          #end
          unless vars.is_a?(Hash)
            errors << %Q`Axis #{axis['id']} value #{index+1} variables are of the wrong type: Hash required: #{value.inspect}`
          end
        end
        axes[axis['id']] = values.map { |value| value['id'] }.compact
      end

      doc['buildvariants']&.each do |variant|
        if spec = variant['matrix_spec']
          spec.each do |axis_name, axis_value|
            unless axes[axis_name]
              errors << %Q`Build variant #{variant['matrix_name']} references nonexistent axis '#{axis_name}'`
              next
            end
            if axis_value == '*'
              next
            end
            Array(axis_value).each do |axis_value|
              unless axes[axis_name].include?(axis_value)
                errors << %Q`Build variant #{variant['matrix_name']} references nonexistent value '#{axis_value}' for axis '#{axis_name}'`
              end
            end
          end
        end
      end

      # Online validators

      if options[:use_service]
        distros = Env.eg_client.distros
        distro_ids = distros.map(&:id)

        doc['buildvariants']&.each do |variant|
          if spec = variant['run_on']
            spec.each do |distro_id|
              found = false
              distros.each do |distro|
                if distro.id == distro_id
                  found = true
                  break
                end
                if distro.aliases&.include?(distro_id)
                  errors << %Q`Build variant '#{variant['name']}' references an alias '#{distro_id}' of distro #{distro.name}`
                  found = true
                  break
                end
              end
              unless found
                errors << %Q`Build variant '#{variant['name']}' references nonexistent distro '#{distro_id}'`
                next
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
