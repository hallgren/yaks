module Yaks
  class Config
    class DSL
      attr_reader :config

      def initialize(config, &blk)
        @config = config
        @policy_class = Class.new(DefaultPolicy)
        @policies     = []
        instance_eval(&blk) if blk
        @policies.each do |policy_blk|
          @policy_class.class_eval &policy_blk
        end
        config.policy_class = @policy_class
      end

      def format_options(format, options)
        config.format_options[format] = options
      end

      def default_format(format)
        config.default_format = format
      end

      def policy(klass)
        @policy_class = klass
      end

      def rel_template(templ)
        config.policy_options[:rel_template] = templ
      end

      def mapper_namespace(namespace)
        config.policy_options[:namespace] = namespace
      end
      alias namespace mapper_namespace

      def map_to_primitive(*args, &blk)
        config.primitivize.map(*args, &blk)
      end

      def after(&block)
        config.steps << block
      end

      DefaultPolicy.public_instance_methods(false).each do |method|
        define_method method do |&blk|
          @policies << proc {
            define_method method, &blk
          }
        end
      end
    end

    attr_accessor :format_options, :default_format, :policy_class, :policy_options, :primitivize, :steps

    def initialize(&blk)
      @format_options = Hash.new({})
      @default_format = :hal
      @policy_options = {}
      @primitivize    = Primitivize.create
      @steps          = [ @primitivize ]
      DSL.new(self, &blk)
    end

    def policy
      @policy_class.new(@policy_options)
    end

    def serializer_class(opts, env)
      if env.key? 'HTTP_ACCEPT'
        accept = Rack::Accept::Charset.new(env['HTTP_ACCEPT'])
        mime_type = accept.best_of(Serializer.mime_types.values)
        return Serializer.by_mime_type(mime_type) if mime_type
      end
      Serializer.by_name(opts.fetch(:format) { @default_format })
    end

    def format_name(opts)
      opts.fetch(:format) { @default_format }
    end

    def options_for_format(format)
      format_options[format]
    end

    # model                => Yaks::Resource
    # Yaks::Resource       => serialized structure
    # serialized structure => serialized flat

    def call(object, opts = {})
      env = opts.fetch(:env, {})
      context = {
        policy: policy,
        env: env,
        mapper_stack: []
      }

      mapper     = opts.fetch(:mapper) { policy.derive_mapper_from_object(object) }.new(context)
      serializer = serializer_class(opts, env).new(format_options[format_name(opts)])

      [ mapper, serializer, *steps ].inject(object) {|memo, step| step.call(memo) }
    end
    alias serialize call
  end
end
