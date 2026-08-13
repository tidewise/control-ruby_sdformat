# frozen_string_literal: true

require "sdf/loader"
require "sdf/test"

describe SDF::Loader do
    it "loads sdf model correctly" do
        loader = SDF::Loader.new

        sdf_file_path = File.expand_path(
            "data/models/simple_model/model.sdf", __dir__
        )
        content = loader.load_sdf_raw(sdf_file_path)

        assert_equal "simple test model",
                     REXML::XPath.first(content, "//model").attributes["name"]
    end

    describe "#loads real file" do
        before(:all) do
            @models_dir = File.expand_path("data/models", __dir__)
            @simple_model = File.join(@models_dir, "/simple_model_erb/model.sdf.erb")
        end

        it "loads a real .sdf.erb file with args" do
            gps_pose = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
            gps2_pose = [6.0, 7.0, 8.0, 9.0, 0.0, 1.0]
            poses = {
                poses: {
                    gps: gps_pose,
                    gps2: gps2_pose
                }
            }
            loader = SDF::Loader.new(erb_args: poses)

            erb_content = loader.load_sdf_raw(@simple_model)

            assert_equal "simple_model_erb",
                         REXML::XPath.first(erb_content, "//model").attributes["name"]
            poses = REXML::XPath.match(erb_content, "//pose").map(&:text)
            assert_includes poses, "0.0 1.0 2.0 3.0 4.0 5.0"
            assert_includes poses, "6.0 7.0 8.0 9.0 0.0 1.0"
        end

        it "InvalidXML when loading erb file with .sdf extension" do
            gps_pose = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
            gps2_pose = [6.0, 7.0, 8.0, 9.0, 0.0, 1.0]
            poses = {
                poses: {
                    gps: gps_pose,
                    gps2: gps2_pose
                }
            }
            loader = SDF::Loader.new(erb_args: poses)

            invalid_models_dir = File.expand_path("data/invalid_models", __dir__)
            invalid_model = File.join(
                invalid_models_dir, "/erb_model_with_sdf_extension/model.sdf"
            )
            error = assert_raises(SDF::XML::InvalidXML) do
                loader.load_sdf_raw(invalid_model)
            end
            assert_match(/Hint: This file appears to be an ERB template/, error.message)
        end

        it "loads a real .sdf.erb file without args" do
            erb_content = SDF::Loader.new.load_sdf_raw(@simple_model)

            assert_equal "simple_model_erb",
                         REXML::XPath.first(erb_content, "//model").attributes["name"]
            poses = REXML::XPath.match(erb_content, "//pose").map(&:text)
            assert_includes poses, "-0.679 0.0 1.92 0.0 0.0 0.0"
            assert_includes poses, "2.571 0.044 0.808 0.0 0.0 0.0"
        end

        it "validates that the file is a XML file" do
            assert_raises(SDF::XML::InvalidXML) do
                SDF::Loader.new.load_sdf_raw(File.join(@models_dir, "not_xml.xml"))
            end
        end
        it "validates that the file has a root" do
            assert_raises(SDF::XML::InvalidXML) do
                SDF::Loader.new.load_sdf_raw(File.join(@models_dir, "no_root.xml"))
            end
        end
        it "validates that the file is a SDF file" do
            assert_raises(SDF::XML::NotSDF) do
                SDF::Loader.new.load_sdf_raw(File.join(@models_dir, "not_sdf.xml"))
            end
        end
        it "validates that the file exists" do
            assert_raises(Errno::ENOENT) do
                SDF::Loader.new.load_sdf_raw(File.join(@models_dir,
                                                       "does_not_exist.xml"))
            end
        end
    end
end
