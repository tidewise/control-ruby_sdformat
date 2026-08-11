# frozen_string_literal: true

require "erb"

module SDF
    # class to load SDF and ERB templated SDF files
    class Loader
        def initialize(erb_args: {})
            @erb_args = erb_args
        end

        # Open a SDF file SDF file and returns its XML representation.
        #
        # @param [String] sdf_file the path to the SDF file
        # @raise [Errno::ENOENT] if the files does not exist
        # @raise [NotSDF] if the file is not a SDF file
        # @raise [InvalidXML] if the file is not a valid XML file
        # @return [REXML::Element] sdf_file's content as a REXML::Element instance
        def load_sdf_raw(sdf_file)
            xml_string = File.read(sdf_file)
            if sdf_file.end_with?(".sdf.erb")
                erb_engine = ::ERB.new(xml_string, trim_mode: "-")
                xml_string = erb_engine.result_with_hash(@erb_args)
            end
            sdf = REXML::Document.new(xml_string)
            validate_sdf_root(sdf, sdf_file)

            sdf
        rescue REXML::ParseException => e
            error_message = "Cannot load #{sdf_file}: #{e.message}"

            if xml_string.match?(/<%.*?%>/m)
                error_message += "\nHint: This file appears to be an ERB template. " \
                                 "Make sure it ends with the extension .sdf.erb"
            end

            raise SDF::XML::InvalidXML, error_message
        end

        private

        def validate_sdf_root(sdf, sdf_file)
            return if sdf.root.name == "sdf"

            raise SDF::XML::NotSDF, "#{sdf_file} is not a SDF file"
        end
    end
end
