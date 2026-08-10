# frozen_string_literal: true

require "erb"
require "sdf/loader"

module SDF
    # class to load SDF and ERB templated SDF files
    class ERBLoader < Loader
        # Parses an ERB string and returns the raw rendered string
        #
        # @param [String] erb_content ERB template file content as string
        # @param [Hash] erb_args the configuration arguments to evaluate
        # @return [String] the raw rendered XML string representing the model
        def self.parse_erb_as_str(erb_content, **erb_args)
            erb_engine = ::ERB.new(erb_content, trim_mode: "-")

            # Render the ERB template with the passed hash arguments
            erb_engine.result_with_hash(erb_args)
        end

        # Renders an ERB template and returns it as a REXML::Document
        #
        # @return [REXML::Document] the rendered sdf model
        def self.render_erb_sdf_model(path, **erb_args)
            erb_content = File.read(path)
            solved_erb_as_sdf_str = parse_erb_as_str(erb_content, **erb_args)

            REXML::Document.new(solved_erb_as_sdf_str)
        end

        def initialize(erb_args: {})
            super()
            @erb_args = erb_args
        end

        def parse_sdf_document(sdf_file)
            ERBLoader.render_erb_sdf_model(sdf_file, **@erb_args)
        end
    end
end
