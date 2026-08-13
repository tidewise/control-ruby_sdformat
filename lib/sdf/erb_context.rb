# frozen_string_literal: true

module SDF
    # class to represent the context for ERB evaluation
    class ERBContext < BasicObject
        class MissingArgumentError < ::ArgumentError; end

        def initialize(args: {})
            @args = deep_symbolize_keys(args)
        end

        def defaults(document)
            @args = deep_merge(deep_symbolize_keys(document), @args)
        end

        # Recursively converts all hash keys to symbols
        def deep_symbolize_keys(val)
            return val unless val.kind_of?(::Hash)

            val.transform_keys(&:to_sym).transform_values { |v| deep_symbolize_keys(v) }
        end

        # Recursively merges defaults with overrides
        def deep_merge(defaults, overrides)
            defaults.merge(overrides) do |_, oldval, newval|
                if oldval.kind_of?(::Hash) && newval.kind_of?(::Hash)
                    deep_merge(oldval, newval)
                else
                    newval
                end
            end
        end

        # rubocop:disable Style/OptionalBooleanParameter
        def respond_to?(method_name, include_all = false)
            sym = method_name.to_sym
            return true if ERBContext.method_defined?(sym)
            return true if include_all && ERBContext.private_method_defined?(sym)

            @args.key?(method_name.to_sym)
        end
        # rubocop:enable Style/OptionalBooleanParameter

        # rubocop:disable Style/MissingRespondToMissing
        def method_missing(method_name, *)
            if @args.key?(method_name)
                val = @args[method_name]
                return val.kind_of?(::Hash) ? ERBContext.new(args: val) : val
            end
            ::Kernel.raise MissingArgumentError.new(
                "no ERB argument available named '#{method_name}'"
            )
        end
        # rubocop:enable Style/MissingRespondToMissing
    end
end
