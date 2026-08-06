# frozen_string_literal: true

require_relative "erb"
require_relative "exceptions"

module SDF
    # class to load SDF and ERB templated SDF files
    class Loader
        # Represents the configuration for rendering a single ERB template.
        class ModelTemplate
            attr_reader :model, :erb_args

            def initialize(
                model,
                erb_args: {}
            )
                @model = model
                @erb_args = (erb_args || {}).transform_keys(&:to_sym)
            end

            def self.from_hash(hash)
                # Convert string keys to symbols to support string-keyed hashes
                symbolized = hash.transform_keys(&:to_sym)
                model = symbolized.fetch(:model) do
                    raise ArgumentError,
                          "The :model key is required when constructing from a Hash"
                end
                options = symbolized.reject { |k| k == :model }
                new(model, **options)
            end

            def model_name
                if @model.start_with?("model://")
                    @model.sub("model://", "").split("/").first
                elsif @model.end_with?(".sdf") || @model.end_with?(".sdf.erb")
                    File.basename(File.dirname(@model))
                else
                    File.basename(@model)
                end
            end
        end

        # Initializes the loader with one or more templates.
        #
        # Supports:
        # - ERBLoader.new(model: "...", erb_args: ...)
        # - ERBLoader.new({ model: "a" }, { model: "b" })
        # - ERBLoader.new([{ model: "a" }, { model: "b" }])
        # - ERBLoader.new(ModelTemplate.new("a"), ModelTemplate.new("b"))
        def initialize(*templates)
            # Unwrap the outer array if multiple templates were passed
            # inside an explicit Array
            if templates.size == 1 && templates.first.kind_of?(Array)
                templates = templates.first
            end
            @templates = templates.map do |template|
                case template
                when ModelTemplate
                    template
                when Hash
                    ModelTemplate.from_hash(template)
                when String
                    ModelTemplate.new(template)
                else
                    raise ArgumentError,
                          "Expected SDF::Loader::ModelTemplate, Hash, or " \
                          "String, got #{template.class}"
                end
            end
        end

        def render_erb_sdf_model(sdf_file)
            target_model_name = File.basename(File.dirname(sdf_file))
            model_config = @templates.find { |t| t.model_name == target_model_name }
            erb_args = model_config&.erb_args || {}
            SDF::ERB.render_erb_sdf_model(sdf_file, **erb_args)
        end

        # Open a SDF file or ERB templated SDF file and returns the XML representation.
        #
        # The input files must have `.sdf` or `.sdf.erb` as its extension
        #
        # @param [String] sdf_file the path to the SDF file
        # @raise [Errno::ENOENT] if the files does not exist
        # @raise [NotSDF] if the file is not a SDF file
        # @raise [InvalidXML] if the file is not a valid XML file
        # @return [REXML::Element] sdf_file's content as a REXML::Element instance
        def load_sdf_raw(sdf_file)
            erb_file = sdf_file.end_with?(".sdf.erb") ? sdf_file : "#{sdf_file}.erb"
            find_or_raise_file_not_found(sdf_file, erb_file)

            sdf = parse_sdf_document(sdf_file, erb_file)
            validate_sdf_root(sdf, sdf_file)

            sdf
        end

        private

        def find_or_raise_file_not_found(sdf_file, erb_file)
            return if File.exist?(sdf_file) || File.exist?(erb_file)

            file_name = File.basename(sdf_file)
            dir_path  = File.dirname(sdf_file)
            msg = if sdf_file.end_with?(".sdf.erb")
                      "Cannot find '#{file_name}' in '#{dir_path}'. "
                  else
                      "Cannot find '#{file_name}' or '#{file_name}.erb' in " \
                          "'#{dir_path}'. "
                  end
            raise Errno::ENOENT,
                  "#{msg}You probably want to update the GAZEBO_MODEL_PATH " \
                  "environment variable, or set SDF.model_path explicitly."
        end

        def parse_sdf_document(sdf_file, erb_file)
            if File.exist?(sdf_file) && !sdf_file.end_with?(".erb")
                File.open(sdf_file) { |io| REXML::Document.new(io) }
            else
                render_erb_sdf_model(erb_file)
            end
        rescue REXML::ParseException => e
            unless e.message.include?("No root")
                raise SDF::XML::InvalidXML,
                      "Cannot load #{sdf_file}: #{e.message}"
            end

            REXML::Document.new
        end

        def validate_sdf_root(sdf, sdf_file)
            unless sdf.root
                raise SDF::XML::NotSDF,
                      "#{sdf_file} can be parsed as an XML file, but it " \
                      "does not have a root"
            end
            return if %w[sdf gazebo].include?(sdf.root.name)

            raise SDF::XML::NotSDF, "#{sdf_file} is not a SDF file"
        end
    end
end
