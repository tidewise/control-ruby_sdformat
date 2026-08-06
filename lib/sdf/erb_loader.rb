# frozen_string_literal: true

require_relative "erb"
require_relative "sdf_loader"

module SDF
    # class to load SDF and ERB templated SDF files
    class ERBLoader < Loader
        def initialize(erb_args: {})
            super()
            @erb_args = erb_args
        end

        def parse_sdf_document(sdf_file)
            SDF::ERB.render_erb_sdf_model(sdf_file, **@erb_args)
        end
    end
end
