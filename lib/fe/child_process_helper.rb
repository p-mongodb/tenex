autoload :ChildProcess, 'childprocess'

module ChildProcessHelper
  module_function def call(cmd, env: nil)
    process = ChildProcess.new(*cmd)
    process.io.inherit!
    if env
      env.each do |k, v|
        process.environment[k.to_s] = v
      end
    end
    process.start
    process.wait
    process
  end

  module_function def check_call(cmd, env: nil)
    process = call(cmd, env: env)
    unless process.exit_code == 0
      raise "Failed to execute: #{cmd}"
    end
  end

  module_function def check_output(cmd, env: nil)
    process = ChildProcess.new(*cmd)
    process.io.inherit!
    process.io.stdout = Tempfile.new("child-output")
    if env
      env.each do |k, v|
        process.environment[k.to_s] = v
      end
    end
    process.start
    process.wait
    unless process.exit_code == 0
      raise "Failed to execute: #{cmd}"
    end
    process.io.stdout.rewind
    process.io.stdout.read
  end
end
