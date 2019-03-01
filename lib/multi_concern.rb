module MultiConcern
  def self.extended(base) #:nodoc:
    base.instance_variable_set(:@_dependencies, [])
  end

  def append_features(base)
    if base.instance_variable_defined?(:@_dependencies)
      base.instance_variable_get(:@_dependencies) << self
      false
    else
      return false if base < self
      @_dependencies.each { |dep| base.include(dep) }
      super
      base.extend const_get(:ClassMethods) if const_defined?(:ClassMethods)
      if instance_variable_defined?(:@_included_blocks)
        @_included_blocks.each do |block|
          base.class_eval(&block)
        end
      end
    end
  end

  def included(base = nil, &block)
    if base.nil?
      if instance_variable_defined?(:@_included_blocks)
        @_included_blocks << block
      else
        @_included_blocks = [block]
      end
    else
      super
    end
  end

  def class_methods(&class_methods_module_definition)
    mod = const_defined?(:ClassMethods, false) ?
      const_get(:ClassMethods) :
      const_set(:ClassMethods, Module.new)

    mod.module_eval(&class_methods_module_definition)
  end
end
