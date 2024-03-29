class Method

  # a single method has been added to instances of Method. When called on a method
  # with arguments matching the existing method signature, the method instance extends
  # behavior contained in WithArgs module.
  #
  # The new Method::WithArgs can now be passed anywhere in code and be called
  # with arguments defined at time of generation.

  def with_args(*args, **named_args)
    extend WithArgs
    self.args = args
    self.named_args = named_args

    validate_args!
    self
  end

  module WithArgs
    # from_hash_splat will regenerate the original Method::WithArgs when
    # the splatted hash was created by calling to_h on a previous Method::WithArgs
    #
    # e.g.
    #
    # m = MyClass.method(:my_method).with_args("gumshoo")
    #
    # method_with_args_hash = m.to_h
    #
    # {
    #   receiver: MyClass,
    #   name: :my_method,
    #   args: ["gumshoo"],
    #   named_args: {}
    # }
    #
    # m2 = Method::WithArgs.from_hash_splat(**method_with_args_hash)
    #
    # m == m2
    # => true
    #
    # m2.receiver
    # => MyClass
    #
    # m2.name
    # => :my_method
    #
    # m2.args
    # => ["gumshoo"]
    #
    # m2.named_args
    # => {}

    def from_hash_splat(receiver:, name:, args:, named_args:)
      Object.const_get(receiver.to_s).
        method(name).
        with_args(*args, **named_args.transform_keys(&:to_sym))
    end
    module_function :from_hash_splat

    def call
      if args.empty? && named_args.empty?
        super
      elsif args.empty?
        super(**named_args)
      elsif named_args.empty?
        super(*args)
      else
        super(*args, **named_args)
      end
    end

    def to_h
      {
        receiver: receiver,
        name: name,
        args: args,
        named_args: named_args
      }
    end

    def source
      receiver.method(name)
    end

    def to_s
      "#<Method::WithArgs: #{receiver.name}.#{name}>"
    end

    def inspect
      to_s.gsub('>', " args: #{args} named_args: #{named_args}>")
    end

    def ==(method_with_args)
      method_with_args.is_a?(Method::WithArgs) &&
        method_with_args.receiver == receiver &&
        method_with_args.name == name &&
        method_with_args.args == args &&
        method_with_args.named_args == named_args
    end

    def args
      @args
    end

    def named_args
      @named_args
    end

    protected

    def validate_args!
      if invalid_args? || invalid_named_args?
        raise ArgumentError, %(
          Method::WithArgs arguments don't match the method signature of the source method:\n\n
          #{source}\n\n
          (NOTE: unbracketed hash arguments aren't supported)
        ).split.join(' ')
      end
    end

    def unnamed_parameters
      parameters.reject do |pair|
        pair.first.to_s.match(/key*/)
      end
    end

    def named_parameters
      parameters.select do |pair|
        pair.first.to_s.match(/key*/)
      end
    end

    def invalid_named_args?
      named_params = named_parameters
      required = named_params.select do |pair|
        pair.first == :keyreq
      end

      unlimited = named_params.any? do |pair|
        pair.first == :keyrest
      end

      missing_required = required.any? do |pair|
        !named_args.keys.include?(pair.last)
      end

      invalid_options = named_args.reject do |k, _v|
        named_params.map(&:last).include?(k)
      end

      missing_required || !unlimited && !invalid_options.empty?
    end

    def invalid_args?
      unnamed_params = unnamed_parameters
      required = unnamed_params.select do |pair|
        pair.first == :req
      end

      unlimited = unnamed_params.any? do |pair|
        pair.first == :rest
      end

      too_many = !unlimited && args.size > unnamed_params.size
      too_few = args.size < required.size

      too_many || too_few
    end

    private

    def args=(args)
      @args = args
    end

    def named_args=(named_args)
      @named_args = named_args
    end

  end
end