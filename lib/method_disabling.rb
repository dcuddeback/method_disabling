# MethodDisabling allows a programmer to programatically disable existing methods, causing them to
# raise a NoMethodError, and restore the methods to their original behavior.
#
# The most obvious use case for disabling messages is when you want to ensure that your unit tests
# don't do anything unexpected, such as connecting to external resources.
module MethodDisabling

  # Provides class-level macros for managing disabled methods.
  #
  # @example Disabling an instance method
  #   class Foo
  #     def bar
  #       42
  #     end
  #   end
  #
  #   Foo.new.bar               # => 42
  #   Foo.disable_method :bar
  #   Foo.new.bar               # => NoMethodError: Foo#bar is disabled
  #   Foo.restore_method :bar
  #   Foo.new.bar               # => 42
  #
  # @example Disabling a class method
  #   class Foo
  #     def self.bar
  #       42
  #     end
  #   end
  #
  #   Foo.bar                         # => 42
  #   Foo.disable_class_method :bar
  #   Foo.bar                         # => NoMethodError: #<Class:Foo>#bar is disabled
  #   Foo.restore_class_method :bar
  #   Foo.bar                         # => 42
  #
  module ClassMethods

    # Disables an instance method.
    #
    # @param [Symbol,String]  method_name   The name of the method to disable.
    # @param [String]         message       An error message. Defaults to "Class#method is disabled".
    def disable_method(method_name, message = nil)
      disabled_methods[method_name] ||= DisabledMethod.new(self, method_name, message)
      disabled_methods[method_name].disable!
    end

    # Restores a previously disabled instance method.
    #
    # @param [Symbol,String]  method_name   The name of the method to restore.
    def restore_method(method_name)
      disabled_methods[method_name].restore!
    end

    # A collection of the methods that have been disabled.
    #
    # @return [Hash]
    def disabled_methods
      @disabled_methods ||= {}
    end
    private :disabled_methods

    # Disables a class method.
    #
    # @param [Symbol,String]  method_name   The name of the method to disable.
    # @param [String]         message       An error message. Defaults to "Class#method is disabled".
    def disable_class_method(method_name, message = nil)
      singleton_class.disable_method(method_name, message)
    end

    # Restores a previously disabled class method.
    #
    # @param [Symbol,String]  method_name   The name of the method to restore.
    def restore_class_method(method_name)
      singleton_class.restore_method(method_name)
    end

  end


  # A DisabledMethod is an existing class or instance method that has been disabled. The method can
  # be disabled and restored as necessary. When the method is disabled, calling the method will
  # raise a NoMethodError, optionally with a custom message. When the method is restored, the method
  # will behave as normal.
  #
  # Although this class *could* be used directly, the intention is that you would use the methods in
  # {MethodDisabling::ClassMethods} to disable and restore methods.
  class DisabledMethod

    attr_reader :klass, :method_name, :message

    # Disables a instance method. To disable a class method, pass the class's singleton class as the
    # first argument.
    #
    # @param [Module]         klass         The module or class whose method should be disabled.
    # @param [Symbol,String]  method_name   The name of the method to disable.
    # @param [String]         message       The exception message to be shown when the method is
    #                                       called.
    def initialize(klass, method_name, message = nil)
      @klass       = klass
      @method_name = method_name
      @message     = message || "#{klass.inspect}##{method_name} is disabled"

      alias_method!
      disable!
    end

    # Disables the method.
    def disable!
      @disabled = true
    end

    # Restores the method.
    def restore!
      @disabled = false
    end

    # Returns a Proc that acts as a replacement for the disabled method.
    def to_proc
      disabled_method = self

      # This proc will be evaluated with "self" set to the original object.
      Proc.new do |*args, &block|
        disabled_method.execute(self, *args, &block)
      end
    end

    # The replacement for the original method. It will raise a NoMethodError if the method is
    # disabled. Otherwise, it will execute the original method.
    #
    # @param [Object] object  The "self" object of the method being called.
    # @param [Array]  args    The arguments that were passed to the method.
    # @param [Proc]   block   The block that was passed to the method.
    #
    # @return Whatever the original method returns.
    def execute(object, *args, &block)
      if disabled?
        raise NoMethodError, message
      else
        object.send(aliased_name, *args, &block)
      end
    end

    private

    # Indicates whether or not the method is disabled.
    #
    # @return [Boolean]
    def disabled?
      @disabled
    end

    # Replaces the original implementation of the method with an implementation that allows
    # disabling.
    def alias_method!
      klass.send(:define_method, replacement_name, &self)
      klass.send(:alias_method, aliased_name, method_name)
      klass.send(:alias_method, method_name, replacement_name)
    end

    # The name of the replacement method.
    #
    # @return [String]
    def replacement_name
      "#{base_method_name}_with_disable#{method_suffix}"
    end

    # The aliased name of the original method.
    #
    # @return [String]
    def aliased_name
      "#{base_method_name}_without_disable#{method_suffix}"
    end

    # The original method name with any suffix ("!" or "?") removed.
    #
    # @return [String]
    def base_method_name
      method_name_parts[:base_name]
    end

    # The original method name's suffix ("!" or "?"), if any.
    #
    # @return [String]
    def method_suffix
      method_name_parts[:suffix]
    end

    # The original method name broken into parts. The returned value can is a hash with the keys
    # `:base_name` and `:suffix`, which return the original method name's base name and suffix,
    # respectively.
    #
    # @return [Hash]
    def method_name_parts
      @parts ||= begin
        base_name, suffix = method_name.to_s.sub(/([?!=]?)$/, ""), $1
        { :base_name => base_name, :suffix => suffix }
      end
    end

  end

end

# Yeah, it's including ClassMethods, which isn't usual, but that's because it's being included on
# the Module class, which effectively makes them class methods in other classes and modules.
Module.send(:include, MethodDisabling::ClassMethods)
