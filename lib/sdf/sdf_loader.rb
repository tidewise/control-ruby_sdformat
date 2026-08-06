# frozen_string_literal: true

require_relative "erb"
require_relative "exceptions"

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
            find_or_raise_file_not_found(sdf_file)

            sdf = begin
                parse_sdf_document(sdf_file)
            rescue REXML::ParseException => e
                unless e.message.include?("No root")
                    raise SDF::XML::InvalidXML,
                          "Cannot load #{sdf_file}: #{e.message}"
                end

                REXML::Document.new
            end
            validate_sdf_root(sdf, sdf_file)

            sdf
        end

        private

        def find_or_raise_file_not_found(sdf_file)
            return if File.exist?(sdf_file)

            file_name = File.basename(sdf_file)
            dir_path  = File.dirname(sdf_file)
            raise Errno::ENOENT,
                  "Cannot find '#{file_name}' in '#{dir_path}'." \
                  "You probably want to update the GAZEBO_MODEL_PATH " \
                  "environment variable, or set SDF.model_path explicitly."
        end

        def parse_sdf_document(sdf_file)
            File.open(sdf_file) do |io|
                REXML::Document.new(io)
            end
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
