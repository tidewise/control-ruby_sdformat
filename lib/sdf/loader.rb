# frozen_string_literal: true

module SDF
    # class to load SDF and ERB templated SDF files
    class Loader
        # Open a SDF file SDF file and returns its XML representation.
        #
        # @param [String] sdf_file the path to the SDF file
        # @raise [Errno::ENOENT] if the files does not exist
        # @raise [NotSDF] if the file is not a SDF file
        # @raise [InvalidXML] if the file is not a valid XML file
        # @return [REXML::Element] sdf_file's content as a REXML::Element instance
        def load_sdf_raw(sdf_file)
            sdf = begin
                parse_sdf_document(sdf_file)
            rescue REXML::ParseException => e
                raise SDF::XML::InvalidXML,
                      "Cannot load #{sdf_file}: #{e.message}"
            end
            validate_sdf_root(sdf, sdf_file)

            sdf
        end

        private

        def parse_sdf_document(sdf_file)
            File.open(sdf_file) do |io|
                REXML::Document.new(io)
            end
        end

        def validate_sdf_root(sdf, sdf_file)
            return if sdf.root.name == "sdf"

            raise SDF::XML::NotSDF, "#{sdf_file} is not a SDF file"
        end
    end
end
