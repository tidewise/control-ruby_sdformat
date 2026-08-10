# frozen_string_literal: true

require "sdf/loader"
require "sdf/test"

describe SDF::Loader do
    it "fallback from .sdf to .sdf.erb and loads file without model and args" do
        loader = SDF::Loader.new

        sdf_file_path = File.expand_path(
            "data/models/simple_model/model.sdf", __dir__
        )
        content = loader.load_sdf_raw(sdf_file_path)

        assert_equal "simple test model",
                     REXML::XPath.first(content, "//model").attributes["name"]
    end
end
