require "sdf/test"

describe SDF::Model do
    def models_dir
        File.join(File.dirname(__FILE__), "data", "models")
    end

    before do
        @model_path = SDF::XML.model_path
        SDF::XML.model_path = [models_dir]
    end
    after do
        SDF::XML.model_path = @model_path
        SDF::XML.clear_cache
    end

    it "can be created as-is" do
        model = SDF::Model.new
        assert model.each_link.to_a.empty?
        assert model.each_joint.to_a.empty?
        assert model.each_plugin.to_a.empty?
        refute model.static?
    end

    describe "load_from_model_name" do
        it "loads a gazebo model from name" do
            model = SDF::Model.load_from_model_name("simple_model")
            assert_equal("simple test model", model.name)
        end
        it "returns the latest SDF version if max_version is nil" do
            model = SDF::Model.load_from_model_name("versioned_model")
            assert_equal("versioned model 1.5", model.name)
        end
        it "returns the latest version matching max_version if provided" do
            model = SDF::Model.load_from_model_name("versioned_model", 130)
            assert_equal("versioned model 1.3", model.name)
        end
        it "raises if the version constraint is not matched" do
            assert_raises(SDF::XML::UnavailableSDFVersionInModel) do
                SDF::Model.load_from_model_name("versioned_model", 0)
            end
        end
    end

    describe "#initialize" do
        it "resolves joints and links so that the declaration order does not matter" do
            model = SDF::Model.from_xml_string(<<-EOXML)
            <model name="m">
                <joint name="j">
                    <parent>parent_l</parent>
                    <child>child_l</child>
                </joint>
                <link name="parent_l" />
                <link name="child_l" />
            </model>
            EOXML
            assert_equal model.find_link_by_name("parent_l"),
                         model.find_joint_by_name("j").parent_link
            assert_equal model.find_link_by_name("child_l"),
                         model.find_joint_by_name("j").child_link
        end
    end

    describe "#find_model_by_name" do
        before do
            xml_s = <<~XML
                <model>
                    <model name="0"><model name="a" /></model>
                    <model name="1" />
                </model>
            XML
            @xml = REXML::Document.new(xml_s).root
            @root = SDF::Model.new(@xml)
        end
        it "returns nil if the model has no " do
            assert_nil @root.find_model_by_name("does_not_exist")
        end
        it "returns a direct model" do
            model = @root.find_model_by_name("1")
            assert_kind_of SDF::Model, model
            assert_equal @xml.elements["model[@name=\"1\"]"], model.xml
        end
        it "returns models recursively" do
            model = @root.find_model_by_name("0::a")
            assert_kind_of SDF::Model, model
            assert_equal @xml.elements["//model[@name=\"a\"]"], model.xml
        end
    end

    describe "#each_model" do
        it "does not yield anything if the model has no models" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_model).to_a.empty?
        end
        it "yields the models otherwise" do
            root = SDF::Model.new(REXML::Document.new("<model><model name=\"0\" /><model name=\"1\" /></model>").root)

            models = root.each_model.to_a
            assert_equal 2, models.size
            models.each do |m|
                assert_kind_of SDF::Model, m
                assert_same root, m.parent
                assert_equal root.xml.elements.to_a("model[@name=\"#{m.name}\"]"), [m.xml]
            end
        end
    end

    describe "#each_direct_model" do
        it "does not yield anything if the model has no models" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_direct_model).to_a.empty?
        end

        it "does not yields the submodel's submodels" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name=\"a\"><model name=\"b\"><model name=\"c\">" \
                    "</model></model></model>"
                ).root
            )

            submodels = root.enum_for(:each_direct_model).to_a
            assert_equal 1, submodels.size
            submodels.each do |m|
                assert_kind_of SDF::Model, m
                assert_same root, m.parent
                assert_equal root.xml.elements.to_a("model[@name=\"#{m.name}\"]"), [m.xml]
            end
        end
        it "yields multiple direct submodels" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name=\"a\"><model name=\"b\"><model name=\"c\">" \
                    "</model><model name=\"d\"></model></model></model>"
                ).root
            )

            submodels = root.enum_for(:each_direct_model).to_a
            assert_equal 1, submodels.size
            submodels.each do |m|
                assert_kind_of SDF::Model, m
                assert_same root, m.parent
                assert_equal root.xml.elements.to_a("model[@name=\"#{m.name}\"]"), [m.xml]
            end
        end
    end

    describe "#each_link" do
        it "does not yield anything if the model has no link" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_link).to_a.empty?
        end
        it "yields the links otherwise" do
            root = SDF::Model.new(REXML::Document.new("<model><link name=\"0\" /><link name=\"1\" /></model>").root)

            links = root.enum_for(:each_link).to_a
            assert_equal 2, links.size
            links.each do |l|
                assert_kind_of SDF::Link, l
                assert_same root, l.parent
                assert_equal root.xml.elements.to_a("link[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end

    describe "#each_direct_link" do
        it "does not yield anything if the model has no link" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_direct_link).to_a.empty?
        end
        it "does not yields the submodel's links" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name=\"a\"><model name=\"b\"><link name=\"0\" />" \
                    "<link name=\"1\" /></model></model>"
                ).root
            )

            links = root.enum_for(:each_direct_link).to_a
            assert_equal 0, links.size
        end
        it "yields the direct links" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name=\"a\"><link name=\"0\" /><link name=\"1\" />" \
                    "<model name=\"b\"></model></model>"
                ).root
            )

            links = root.enum_for(:each_direct_link).to_a
            assert_equal 2, links.size
            links.each do |l|
                assert_kind_of SDF::Link, l
                assert_same root, l.parent
                assert_equal root.xml.elements.to_a("link[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end

    describe "#each_plugin" do
        it "does not yield anything if the model has no plugin" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_plugin).to_a.empty?
        end
        it "yields the plugins otherwise" do
            root = SDF::Model.new(REXML::Document.new("<model><plugin name=\"0\" /><plugin name=\"1\" /></model>").root)

            plugin = root.enum_for(:each_plugin).to_a
            assert_equal 2, plugin.size
            plugin.each do |l|
                assert_kind_of SDF::Plugin, l
                assert_same root, l.parent
                assert_equal root.xml.elements.to_a("plugin[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end

    describe "#each_direct_plugin" do
        it "does not yield anything if the model has no plugin" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_direct_plugin).to_a.empty?
        end
        it "does not yields the submodel's plugins" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name=\"a\"><model name=\"b\"><plugin name=\"0\" />" \
                    "<plugin name=\"1\" /></model></model>"
                ).root
            )

            plugins = root.enum_for(:each_direct_plugin).to_a
            assert_equal 0, plugins.size
        end
        it "yields the direct plugins" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name=\"a\"><plugin name=\"0\" /><plugin name=\"1\" />" \
                    "<model name=\"b\"></model></model>"
                ).root
            )

            plugins = root.enum_for(:each_direct_plugin).to_a
            assert_equal 2, plugins.size
            plugins.each do |l|
                assert_kind_of SDF::Plugin, l
                assert_same root, l.parent
                assert_equal root.xml.elements.to_a("plugin[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end

    describe "#each_sensor" do
        it "does not yield anything if the model has no sensor link" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_sensor).to_a.empty?
        end
        it "yields the links sensor otherwise" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model><link name=\"0\"><sensor name=\"a\"/></link>" \
                    "<link name=\"1\"><sensor name=\"b\" /></link></model>"
                ).root
            )

            sensors = root.enum_for(:each_sensor).to_a
            assert_equal 2, sensors.size
            sensors.each do |s|
                assert_kind_of SDF::Sensor, s
                assert_equal(
                    root.xml.elements.to_a("link/sensor[@name=\"#{s.name}\"]"), [s.xml]
                )
            end
        end
    end

    describe "#each_direct_sensor" do
        it "does not yield anything if the model has no link" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_direct_link).to_a.empty?
        end
        it "does not yields the submodel's sensors" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name=\"a\"><model name=\"b\"><link name=\"0\">" \
                    "<sensor name=\"a\"/></link><link name=\"1\"><sensor name=\"b\"/>" \
                    "</link></model></model>"
                ).root
            )

            sensors = root.enum_for(:each_direct_sensor).to_a
            assert_equal 0, sensors.size
        end
        it "yields the direct sensors" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name=\"a\"><link name=\"0\"><sensor name=\"a\"/></link>" \
                    "<link name=\"1\"><sensor name=\"b\"/></link><model name=\"b\">" \
                    "</model></model>"
                ).root
            )

            sensors = root.enum_for(:each_direct_sensor).to_a
            assert_equal 2, sensors.size
            sensors.each do |s|
                assert_kind_of SDF::Sensor, s
                assert_equal(
                    root.xml.elements.to_a("link/sensor[@name=\"#{s.name}\"]"), [s.xml]
                )
            end
        end
    end

    describe "#each_joint" do
        it "does not yield anything if the model has no joint" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_joint).to_a.empty?
        end
        it "yields the joints otherwise" do
            root = SDF::Model.new(REXML::Document.new("<model><link name='parent' /><link name='child' /><joint name=\"0\"><parent>parent</parent><child>child</child></joint><joint name=\"1\"><parent>parent</parent><child>child</child>/></joint></model>").root)

            joints = root.enum_for(:each_joint).to_a
            assert_equal 2, joints.size
            joints.each do |l|
                assert_kind_of SDF::Joint, l
                assert_same root, l.parent
                assert_equal root.xml.elements.to_a("joint[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end

    describe "#find_joint_by_name" do
        before do
            @root = SDF::Model.new(REXML::Document.new(<<-EOXML).root)
            <model name="root">
                <link name='parent_l' />
                <model name="child_m">
                    <link name='parent_l' />
                    <link name='child_l' />
                    <joint name="child_j">
                        <parent>parent_l</parent>
                        <child>child_l</child>
                    </joint>
                </model>
                <joint name="root_j">
                    <parent>parent_l</parent>
                    <child>child_m::child_l</child>
                </joint>
            </model>
            EOXML
        end

        it "find a joint in a toplevel model" do
            joint = @root.find_joint_by_name("root_j")
            assert_equal @root.find_link_by_name("parent_l"),
                         joint.parent_link
            assert_equal @root.find_link_by_name("child_m::child_l"),
                         joint.child_link
        end

        it "finds a joint in a child model" do
            joint = @root.find_joint_by_name("child_m::child_j")
            assert_equal @root.find_link_by_name("child_m::parent_l"), joint.parent_link
            assert_equal @root.find_link_by_name("child_m::child_l"), joint.child_link
        end
    end

    describe "#each_direct_joint" do
        it "does not yield anything if the model has no joint" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_direct_joint).to_a.empty?
        end

        it "doesnt yield the submodel's joints" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name='a'><model name='b'><link name='parent' />" \
                    "<link name='child' /><joint name=\"0\"><parent>parent</parent><child>" \
                    "child</child></joint><joint name=\"1\"><parent>parent</parent>" \
                    "<child>child</child>/></joint></model></model>"
                ).root
            )

            joints = root.enum_for(:each_direct_joint).to_a
            assert_equal 0, joints.size
        end

        it "yields the joints otherwise" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name='a'><link name='parent' /><link name='child' />" \
                    "<joint name=\"0\"><parent>parent</parent><child>child</child></joint>" \
                    "<joint name=\"1\"><parent>parent</parent><child>child</child>/>" \
                    "</joint><model name='b'></model></model>"
                ).root
            )

            joints = root.enum_for(:each_direct_joint).to_a
            assert_equal 2, joints.size
            joints.each do |l|
                assert_kind_of SDF::Joint, l
                assert_same root, l.parent
                assert_equal root.xml.elements.to_a("joint[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end

    describe "#find_link_by_name" do
        before do
            @xml = REXML::Document.new(<<-EOXML).root
            <model name="root">
                <link name='parent_l' />
                <model name="child_m">
                    <link name='parent_l' />
                </model>
            </model>
            EOXML
            @root = SDF::Model.new(@xml)
        end

        it "finds a link in a toplevel model" do
            assert_equal @xml.elements["/model/link"],
                         @root.find_link_by_name("parent_l").xml
        end

        it "find a link in a child model" do
            assert_equal @xml.elements["/model/model/link"],
                         @root.find_link_by_name("child_m::parent_l").xml
        end
    end

    describe "#static?" do
        it "returns false unless specified otherwise" do
            xml = REXML::Document.new("<model />").root
            assert !SDF::Model.new(xml).static?
        end
        it "returns the converted value if a static tag is present" do
            xml = REXML::Document.new("<model><static>foobar</static></model>").root
            flexmock(SDF::Conversions).should_receive(:to_boolean).once.with(xml.elements["static"]).and_return(v = flexmock)
            assert_equal v, SDF::Model.new(xml).static?
        end
    end

    describe "#pose" do
        it "returns the model's pose" do
            xml = REXML::Document.new("<model><pose>1 2 3 0 0 2</pose></model>").root
            model = SDF::Model.new(xml)
            p = model.pose
            assert Eigen::Vector3.new(1, 2, 3).approx?(p.translation)
            assert Eigen::Quaternion.from_angle_axis(2,
                                                     Eigen::Vector3.UnitZ).approx?(p.rotation)
        end
    end

    describe "the canonical link" do
        it "is nil if the model has no link" do
            xml = REXML::Document.new("<model />").root
            model = SDF::Model.new(xml)
            refute model.canonical_link
        end
        it "returns the first link at its level for root models" do
            xml = REXML::Document.new('<model><link name="l" /></model>').root
            model = SDF::Model.new(xml)
            assert_equal "l", model.canonical_link.name
        end
        it "returns the parent's model canonical link for submodels, if it has one" do
            xml = REXML::Document.new('<model><link name="l" /><model name="sub" /></model>').root
            model = SDF::Model.new(xml)
            subm = model.each_model.first
            assert_equal model.canonical_link, subm.canonical_link
        end
        it "returns the first submodel link, even if the parent has a link" do
            xml = REXML::Document.new(
                '<model><link name="parent_l" /><model name="sub"><link name="sub_l" /></model></model>'
            ).root
            model = SDF::Model.new(xml)
            subm = model.each_model.first
            assert_equal subm.each_link.first, subm.canonical_link
        end
        it "uses the submodel's canonical link if it has no link of its own" do
            xml = REXML::Document.new('<model><model name="sub"><link name="l" /></model></model>').root
            model = SDF::Model.new(xml)
            subm = model.each_model.first
            assert_equal subm.each_link.first, model.canonical_link
        end
        it "uses the second submodel's canonical link if it has no link of its own and the first doesn't have a link either" do
            xml = REXML::Document.new('<model><model name="first" /><model name="sub"><link name="l" /></model></model>').root
            model = SDF::Model.new(xml)
            submodels = model.each_model.to_a
            expected = submodels[1].canonical_link
            assert_equal expected, submodels[0].canonical_link
            assert_equal expected, model.canonical_link
        end
        it "returns its first link if the parent model has no canonical link" do
            xml = REXML::Document.new('<model><model name="sub"><link name="l" /></model></model>').root
            model = SDF::Model.new(xml)
            subm = model.each_model.first
            assert_equal subm.each_link.first, subm.canonical_link
        end
    end

    describe "model enumeration" do
        it "enumerates the models" do
            xml = REXML::Document.new(<<-EOXML).root
            <model>
              <model name="test0" />
              <model name="test1" />
            </model>
            EOXML
            model = SDF::Model.new(xml)
            assert_equal %w[test0 test1], model.each_model.map(&:name)
        end

        it "enumerates its children model's models" do
            xml = REXML::Document.new(<<-EOXML).root
            <model>
              <model name="test0">
                <model name="test1">
                  <model name="test2" />
                </model>
              </model>
            </model>
            EOXML
            model = SDF::Model.new(xml)
            assert_equal([["test0", "test0"], ["test1", "test0::test1"], ["test2", "test0::test1::test2"]],
                         model.each_model_with_name.map do |model, name|
                             [model.name, name]
                         end)
        end
    end

    describe "link enumeration" do
        it "enumerates the links" do
            xml = REXML::Document.new(<<-EOXML).root
            <model>
              <link name="test0" />
              <link name="test1" />
            </model>
            EOXML
            model = SDF::Model.new(xml)
            assert_equal %w[test0 test1], model.each_link.map(&:name)
        end

        it "enumerates its children model's links" do
            xml = REXML::Document.new(<<-EOXML).root
            <model>
              <link name="test0" />
              <model name="sub">
                <link name="test1" />
                <model name="subsub">
                  <link name="test2" />
                </model>
              </model>
            </model>
            EOXML
            model = SDF::Model.new(xml)
            assert_equal([["test0", "test0"], ["test1", "sub::test1"], ["test2", "sub::subsub::test2"]],
                         model.each_link_with_name.map { |link, name| [link.name, name] })
        end
    end

    describe "frame enumeration" do
        it "enumerates the frames" do
            xml = REXML::Document.new(<<-EOXML).root
            <model>
              <frame name="test0" />
              <frame name="test1" />
            </model>
            EOXML
            model = SDF::Model.new(xml)
            assert_equal %w[test0 test1], model.each_frame.map(&:name)
        end

        it "enumerates its children model's frames" do
            xml = REXML::Document.new(<<-EOXML).root
            <model>
              <model name="sub">
              <frame name="test0" />
              <frame name="test1" />
              </model>
            </model>
            EOXML
            model = SDF::Model.new(xml)
            assert_equal([["test0", "sub::test0"], ["test1", "sub::test1"]],
                         model.each_frame_with_name.map do |frame, name|
                             [frame.name, name]
                         end)
        end
    end

    describe "#each_direct_frame" do
        it "does not yield anything if the model has no frame" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_direct_frame).to_a.empty?
        end

        it "doesnt yield the submodel's frame" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name='a'><model name='b'><frame name=\"0\"/>" \
                    "<frame name=\"1\"/></model></model>"
                ).root
            )

            frames = root.enum_for(:each_direct_frame).to_a
            assert_equal 0, frames.size
        end

        it "yields the frames otherwise" do
            root = SDF::Model.new(
                REXML::Document.new(
                    "<model name='a'><frame name=\"0\"/><frame name=\"1\"/>" \
                    "<model name='b'></model></model>"
                ).root
            )

            frames = root.enum_for(:each_direct_frame).to_a
            assert_equal 2, frames.size
            frames.each do |l|
                assert_kind_of SDF::Frame, l
                assert_same root, l.parent
                assert_equal root.xml.elements.to_a("frame[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end
end
