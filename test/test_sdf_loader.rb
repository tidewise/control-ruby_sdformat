# frozen_string_literal: true

require "sdf/test"

describe SDF::Loader do
    describe "normalization and initialization" do
        it "normalizes a plain String model name" do
            loader = SDF::Loader.new("model://simple_model")
            templates = loader.instance_variable_get(:@templates)
            assert_equal 1, templates.size
            assert_equal "model://simple_model", templates.first.model
        end

        it "normalizes a single Hash representation passed as keywords directly" do
            loader = SDF::Loader.new(
                model: "model://direct_hash_model",
                erb_args: { val: 42 }
            )
            templates = loader.instance_variable_get(:@templates)
            assert_equal 1, templates.size
            assert_equal "model://direct_hash_model", templates.first.model
            assert_equal({ val: 42 }, templates.first.erb_args)
        end

        it "normalizes multiple hashes passed as separate arguments" do
            loader = SDF::Loader.new(
                { model: "model://model_a" },
                { model: "model://model_b" }
            )
            templates = loader.instance_variable_get(:@templates)
            assert_equal 2, templates.size
            assert_equal "model://model_a", templates[0].model
            assert_equal "model://model_b", templates[1].model
        end

        it "normalizes a single ModelTemplate object directly" do
            template_obj = SDF::Loader::ModelTemplate.new(
                "model://template_obj"
            )
            loader = SDF::Loader.new(template_obj)
            templates = loader.instance_variable_get(:@templates)
            assert_equal 1, templates.size
            assert_equal "model://template_obj", templates.first.model
        end

        it "normalizes an array of mixed types" do
            template_obj = SDF::Loader::ModelTemplate.new("model://object_model")
            loader = SDF::Loader.new([
                                         "model://string_model",
                                         { model: "model://hash_model" },
                                         template_obj
                                     ])
            templates = loader.instance_variable_get(:@templates)
            assert_equal 3, templates.size

            assert_equal "model://string_model", templates[0].model
            assert_equal "model://hash_model", templates[1].model
            assert_equal "model://object_model", templates[2].model
        end

        it "fails fast if a Hash is missing the required :model key" do
            assert_raises(ArgumentError) do
                SDF::Loader.new(erb_args: { key: "val" })
            end
        end

        it "fails fast if passed an unsupported parameter type" do
            assert_raises(ArgumentError) do
                SDF::Loader.new(12_345)
            end
        end

        it "extracts the correct model name for bare strings" do
            template = SDF::Loader::ModelTemplate.new("my_model")
            assert_equal "my_model", template.model_name
        end

        it "extracts the correct model name for local directory paths" do
            template = SDF::Loader::ModelTemplate.new("/path/to/my_model")
            assert_equal "my_model", template.model_name
        end

        it "normalizes hashes with string keys" do
            loader = SDF::Loader.new("model" => "model://string_hash_model",
                                     "erb_args" => { val: 42 })
            templates = loader.instance_variable_get(:@templates)
            assert_equal 1, templates.size
            assert_equal "model://string_hash_model", templates.first.model
            assert_equal({ val: 42 }, templates.first.erb_args)
        end

        it "normalizes string keys inside erb_args to symbols" do
            loader = SDF::Loader.new(
                model: "model://simple_model_erb",
                erb_args: { "links" => [] }
            )
            templates = loader.instance_variable_get(:@templates)
            assert_equal({ links: [] }, templates.first.erb_args)
        end
    end

    describe "#loads real file" do
        it "loads a real .sdf.erb file with args" do
            erb_args = {
                links: [
                    {
                        name: "gps",
                        pose: [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
                    },
                    {
                        name: "gps2",
                        pose: [6.0, 7.0, 8.0, 9.0, 0.0, 1.0]
                    }
                ]
            }
            loader = SDF::Loader.new(
                {
                    model: "model://simple_model_erb",
                    erb_args: erb_args
                }
            )

            erb_file_path = File.expand_path(
                "data/models/simple_model_erb/model.sdf.erb", __dir__
            )
            erb_content = loader.load_sdf_raw(erb_file_path)

            assert_equal "simple_model_erb",
                         REXML::XPath.first(erb_content, "//model").attributes["name"]
            poses = REXML::XPath.match(erb_content, "//pose").map(&:text)
            assert_includes poses, "0.0 1.0 2.0 3.0 4.0 5.0"
            assert_includes poses, "6.0 7.0 8.0 9.0 0.0 1.0"
        end

        it "loads a real .sdf.erb file without args" do
            loader = SDF::Loader.new(
                {
                    model: "model://simple_model_erb"
                }
            )

            erb_file_path = File.expand_path(
                "data/models/simple_model_erb/model.sdf.erb", __dir__
            )
            erb_content = loader.load_sdf_raw(erb_file_path)

            assert_equal "simple_model_erb",
                         REXML::XPath.first(erb_content, "//model").attributes["name"]
            poses = REXML::XPath.match(erb_content, "//pose").map(&:text)
            assert_includes poses, "-0.679 0.0 1.92 0.0 0.0 0.0"
            assert_includes poses, "2.571 0.044 0.808 0.0 0.0 0.0"
        end

        it "fallback from .sdf to .sdf.erb and loads file with args" do
            erb_args = {
                links: [
                    {
                        name: "gps",
                        pose: [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
                    },
                    {
                        name: "gps2",
                        pose: [6.0, 7.0, 8.0, 9.0, 0.0, 1.0]
                    }
                ]
            }
            loader = SDF::Loader.new(
                {
                    model: "model://simple_model_erb",
                    erb_args: erb_args
                }
            )

            erb_file_path = File.expand_path("data/models/simple_model_erb/model.sdf",
                                             __dir__)
            erb_content = loader.load_sdf_raw(erb_file_path)

            assert_equal "simple_model_erb",
                         REXML::XPath.first(erb_content, "//model").attributes["name"]
            poses = REXML::XPath.match(erb_content, "//pose").map(&:text)
            assert_includes poses, "0.0 1.0 2.0 3.0 4.0 5.0"
            assert_includes poses, "6.0 7.0 8.0 9.0 0.0 1.0"
        end

        it "fallback from .sdf to .sdf.erb and loads file without args" do
            loader = SDF::Loader.new(
                {
                    model: "model://simple_model_erb"
                }
            )

            erb_file_path = File.expand_path("data/models/simple_model_erb/model.sdf",
                                             __dir__)
            erb_content = loader.load_sdf_raw(erb_file_path)

            assert_equal "simple_model_erb",
                         REXML::XPath.first(erb_content, "//model").attributes["name"]
            poses = REXML::XPath.match(erb_content, "//pose").map(&:text)
            assert_includes poses, "-0.679 0.0 1.92 0.0 0.0 0.0"
            assert_includes poses, "2.571 0.044 0.808 0.0 0.0 0.0"
        end

        it "fallback from .sdf to .sdf.erb and loads file without model and args" do
            loader = SDF::Loader.new

            erb_file_path = File.expand_path("data/models/simple_model_erb/model.sdf",
                                             __dir__)
            erb_content = loader.load_sdf_raw(erb_file_path)

            assert_equal "simple_model_erb",
                         REXML::XPath.first(erb_content, "//model").attributes["name"]
            poses = REXML::XPath.match(erb_content, "//pose").map(&:text)
            assert_includes poses, "-0.679 0.0 1.92 0.0 0.0 0.0"
            assert_includes poses, "2.571 0.044 0.808 0.0 0.0 0.0"
        end

        it "loads a template with string-keyed erb_args successfully without crashing" do
            loader = SDF::Loader.new(
                model: "model://simple_model_erb",
                erb_args: { "links" => [] }
            )
            erb_file_path = File.expand_path(
                "data/models/simple_model_erb/model.sdf.erb", __dir__
            )
            erb_content = loader.load_sdf_raw(erb_file_path)
            assert_equal "simple_model_erb",
                         REXML::XPath.first(erb_content, "//model").attributes["name"]
        end

        it "has a clean error message for missing .sdf.erb files" do
            loader = SDF::Loader.new
            err = assert_raises(Errno::ENOENT) do
                loader.load_sdf_raw("/path/to/missing_file.sdf.erb")
            end
            refute_match(/\.sdf\.erb\.erb/, err.message)
        end
    end
end
