require "sdf/test"

describe SDF::Root do
    def models_dir
        File.join(File.dirname(__FILE__), "data", "models")
    end

    def regressions_dir
        File.join(File.dirname(__FILE__), "data", "regressions")
    end

    before do
        @model_path = SDF::XML.model_path
        SDF::XML.model_path = [models_dir]
    end
    after do
        SDF::XML.model_path = @model_path
        SDF::XML.clear_cache
    end

    describe "load_from_model_name" do
        it "loads a gazebo model from name" do
            root = SDF::Root.load_from_model_name("simple_model")
            model = root.xml.elements.enum_for(:each, "model").first
            assert_equal("simple test model", model.attributes["name"])
        end
        it "returns the latest SDF version if max_version is nil" do
            root = SDF::Root.load_from_model_name("versioned_model")
            model = root.xml.elements.enum_for(:each, "model").first
            assert_equal("versioned model 1.5", model.attributes["name"])
        end
        it "returns the latest version matching max_version if provided" do
            root = SDF::Root.load_from_model_name("versioned_model", 130)
            model = root.xml.elements.enum_for(:each, "model").first
            assert_equal("versioned model 1.3", model.attributes["name"])
        end
        it "raises if the version constraint is not matched" do
            assert_raises(SDF::XML::UnavailableSDFVersionInModel) do
                SDF::Root.load_from_model_name("versioned_model", 0)
            end
        end
    end

    describe "load" do
        it "loads a SDF file if given a path" do
            root = SDF::Root.load(File.join(models_dir, "simple_model", "model.sdf"))
            model = root.xml.elements.enum_for(:each, "model").first
            assert_equal("simple test model", model.attributes["name"])
        end
        it "validates that the file is a SDF file" do
            assert_raises(SDF::XML::NotSDF) do
                SDF::Root.load(File.join(models_dir, "not_sdf.xml"))
            end
        end
        it "validates that the file exists" do
            assert_raises(Errno::ENOENT) do
                SDF::Root.load(File.join(models_dir, "does_not_exist.xml"))
            end
        end
        it "load each models direct children from root" do
            root = SDF::Root.load(File.join(models_dir, "model_with_includes",
                                            "model.sdf"))
            model_names = []
            root.each_model do |m|
                model_names << m.name
            end
            assert_equal ["simple test model"], model_names
        end
        it "calls load_from_model_name if given a URI" do
            version = flexmock
            flexmock(SDF::Root).should_receive(:load_from_model_name).once.with(
                "model_in_uri", version, flatten: true
            ).and_return(obj = flexmock)
            assert_equal obj, SDF::Root.load("model://model_in_uri", version)
        end
    end

    describe "#find_all_included_models" do
        it "returns the Model objects of the loaded models" do
            root = SDF::Root.load_from_model_name("includes_at_each_level",
                                                  flatten: false)
            models = root.find_all_included_models("model://simple_model").map(&:full_name)

            expected = [
                "w::child_of_world",
                "w::model::child_of_model",
                "w::model::model_in_model::child_of_model_in_model",
                "root_model::child_of_root_model",
                "root_model::model_in_root_model::child_of_model_in_root_model"
            ]
            assert_equal expected, models
        end

        it "handles a full path" do
            full_path = SDF::XML.model_path_from_name("simple_model")
            root = SDF::Root.load_from_model_name("includes_at_each_level",
                                                  flatten: false)
            models = root.find_all_included_models(full_path).map(&:full_name)

            expected = [
                "w::child_of_world",
                "w::model::child_of_model",
                "w::model::model_in_model::child_of_model_in_model",
                "root_model::child_of_root_model",
                "root_model::model_in_root_model::child_of_model_in_root_model"
            ]
            assert_equal expected, models
        end
    end

    describe "#find_file_of" do
        it "returns nil if there is no files involved" do
            root = SDF::Root.new(REXML::Document.new(<<~SDF).root)
                <sdf>
                    <world name="w0" />"
                </sdf>
            SDF
            refute root.find_file_of(root.each_world.first)
        end
        it "returns the toplevel file if there are no includes" do
            root = SDF::Root.new(REXML::Document.new(<<~SDF).root)
                <sdf>
                    <world name="w0" />"
                </sdf>
            SDF
            refute root.find_file_of(root.each_world.first)
        end
        it "returns the toplevel file for the root itself" do
            root = SDF::Root.load_from_model_name(
                "includes_at_each_level", flatten: false
            )
            assert_equal File.join(models_dir, "includes_at_each_level", "model.sdf"),
                         root.find_file_of(root)
        end
        it "returns the toplevel file for an element defined by the main file" do
            root = SDF::Root.load_from_model_name(
                "includes_at_each_level", flatten: false
            )
            assert_equal File.join(models_dir, "includes_at_each_level", "model.sdf"),
                         root.find_file_of(root.each_world.first)
        end
        it "returns the included file when given its root element" do
            root = SDF::Root.load_from_model_name(
                "includes_at_each_level", flatten: false
            )
            assert_equal File.join(models_dir, "simple_model", "model.sdf"),
                         root.find_file_of(root.find_by_name("w::child_of_world"))
        end
        it "returns the included file when given a non-root element" do
            root = SDF::Root.load_from_model_name(
                "includes_at_each_level", flatten: false
            )
            assert_equal File.join(models_dir, "simple_model", "model.sdf"),
                         root.find_file_of(root.find_by_name("w::child_of_world::link"))
        end
        it "returns the included file when given a root of an include-in-include" do
            SDF::XML.model_path << regressions_dir
            root = SDF::Root.load(
                File.join(regressions_dir, "dual_ur10.world"), flatten: false
            )
            assert_equal File.join(regressions_dir, "ur10", "ur10.sdf"),
                         root.find_file_of(root.find_by_name("empty_world::dual_ur10_fixed::dual_ur10::left_arm"))
        end
        it "returns the included file when given a non-root element of an include-in-include" do
            SDF::XML.model_path << regressions_dir
            root = SDF::Root.load(
                File.join(regressions_dir, "dual_ur10.world"), flatten: false
            )
            assert_equal File.join(regressions_dir, "ur10", "ur10.sdf"),
                         root.find_file_of(root.find_by_name("empty_world::dual_ur10_fixed::dual_ur10::left_arm::base"))
        end
    end

    describe "each_world" do
        it "does not yield anything if no worlds are defined" do
            root = SDF::Root.new(REXML::Document.new("<sdf></sdf>").root)
            assert root.each_world.to_a.empty?
        end
        it "yields the worlds otherwise" do
            root = SDF::Root.new(REXML::Document.new("<sdf><world name=\"w0\" /><world name=\"w1\"><world name=\"recursive_should_be_ignored\" /></world></sdf>").root)

            worlds = root.each_world.to_a
            assert_equal 2, worlds.size
            worlds.each do |w|
                assert_kind_of SDF::World, w
                assert_equal root.xml.elements.to_a("world[@name=\"#{w.name}\"]"), [w.xml]
            end
        end
    end

    describe "each_model" do
        it "does not yield anything if no models are defined" do
            root = SDF::Root.new(REXML::Document.new("<sdf></sdf>").root)
            assert root.enum_for(:each_model).to_a.empty?
        end
        it "yields the models otherwise" do
            root = SDF::Root.new(REXML::Document.new("<sdf><model name=\"w0\" /><model name=\"w1\"><model name=\"recursive_should_be_ignored\" /></model></sdf>").root)

            models = root.enum_for(:each_model).to_a
            assert_equal 2, models.size
            models.each do |w|
                assert_kind_of SDF::Model, w
                assert_equal root.xml.elements.to_a("model[@name=\"#{w.name}\"]"), [w.xml]
            end
        end
        it "enumerates models within a world if recursive is set" do
            root = SDF::Root.new(REXML::Document.new("<sdf><world name=\"w\"><model name=\"child_model\"/></world><model name=\"root_model\"/></sdf>").root)

            models = root.each_model(recursive: true).to_a
            assert_equal 2, models.size
            models.each do |w|
                assert_kind_of SDF::Model, w
                assert %w[child_model root_model].include?(w.name)
                assert_equal root.xml.elements.to_a("//model[@name=\"#{w.name}\"]"),
                             [w.xml]
            end
        end
    end

    describe "#version" do
        it "returns an integer-encoded version number" do
            root = SDF::Root.from_xml_string('<sdf version="1.5"/>')
            assert_equal 150, root.version
        end
        it "returns nil if the version attribute is not set" do
            root = SDF::Root.from_xml_string("<sdf />")
            assert_nil root.version
        end
    end
end
