# frozen_string_literal: true

require "erb"

module SDF
    # Module for handling ERB files
    module ERB
        module_function

        # Open an .erb file and returns its content as a string
        #
        # @param [String] file_path path to the .erb template file
        # @return [String] erb file content as a string
        #
        # @raise [ArgumentError] if the file path is not a .erb file,
        # is invalid, or is unreadable
        def read_erb_file(file_path)
            unless file_path.end_with?(".erb")
                raise ArgumentError,
                      "Provided file path must have a '.erb' extension: #{file_path}"
            end

            begin
                erb_content = File.read(file_path)
            rescue Errno::ENOENT
                raise ArgumentError, "ERB template file not found at: #{file_path}"
            rescue Errno::EACCES
                raise ArgumentError,
                      "Permission denied reading ERB template at: #{file_path}"
            end
            erb_content
        end

        # Parses an ERB string and returns the raw rendered string
        #
        # @param [String] erb_content ERB template file content as string
        # @param [Hash] erb_args the configuration arguments to evaluate
        # @return [String] the raw rendered XML string representing the model
        def parse_erb_as_str(erb_content, **erb_args)
            erb_engine = ::ERB.new(erb_content, trim_mode: "-")

            # Render the ERB template with the passed hash arguments
            erb_engine.result_with_hash(erb_args)
        end

        # Renders an ERB template and returns it as a REXML::Document
        #
        # @return [REXML::Document] the rendered sdf model
        def render_erb_sdf_model(path, **erb_args)
            erb_content = read_erb_file(path)
            solved_erb_as_sdf_str = parse_erb_as_str(erb_content, **erb_args)

            REXML::Document.new(solved_erb_as_sdf_str)
        end
    end
end
