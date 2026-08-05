require "sdf/test"

describe SDF::XML do
    def models_dir
        File.join(File.dirname(__FILE__), "data", "models")
    end

    def regressions_dir
        File.join(File.dirname(__FILE__), "data", "regressions")
    end

    def invalid_models_dir
        File.join(File.dirname(__FILE__), "data", "invalid_models")
    end

    before do
        @model_path = SDF::XML.model_path
        SDF::XML.model_path = [models_dir]
    end
    after do
        SDF::XML.model_path = @model_path
        SDF::XML.clear_cache
    end

    describe "load_gazebo_model" do
        it "loads a gazebo model" do
            sdf = SDF::XML.load_gazebo_model(File.join(models_dir, "simple_model"))
            model = sdf.elements.enum_for(:each, "sdf/model").first
            assert_equal("simple test model", model.attributes["name"])
        end
        it "returns the latest SDF version if max_version is nil" do
            sdf = SDF::XML.load_gazebo_model(File.join(models_dir, "versioned_model"))
            model = sdf.elements.enum_for(:each, "sdf/model").first
            assert_equal("versioned model 1.5", model.attributes["name"])
        end
        it "handles unversioned config files" do
            sdf = SDF::XML.load_gazebo_model(File.join(models_dir,
                                                       "model_without_version"))
            model = sdf.elements.enum_for(:each, "sdf/model").first
            assert_equal("model without version", model.attributes["name"])
        end
        it "returns the latest version matching max_version if provided" do
            sdf = SDF::XML.load_gazebo_model(
                File.join(models_dir, "versioned_model"),
                130
            )
            model = sdf.elements.enum_for(:each, "sdf/model").first
            assert_equal("versioned model 1.3", model.attributes["name"])
        end
        it "raises if the version constraint is not matched" do
            assert_raises(SDF::XML::UnavailableSDFVersionInModel) do
                SDF::XML.load_gazebo_model(
                    File.join(models_dir, "versioned_model"),
                    0
                )
            end
        end
    end

    describe "gazebo_models" do
        it "loads all models available in the path" do
            models = SDF::XML.gazebo_models
            assert_equal 23, models.size

            assert(sdf = models["simple_model"])
            model = sdf.elements.enum_for(:each, "sdf/model").first
            assert_equal("simple test model", model.attributes["name"])

            assert(sdf = models["versioned_model"])
            model = sdf.elements.enum_for(:each, "sdf/model").first
            assert_equal("versioned model 1.5", model.attributes["name"])
        end

        it "versions the models" do
            # Load up-to-date models to make sure we re-load for specific
            # versions
            SDF::XML.gazebo_models
            models = SDF::XML.gazebo_models(130)
            assert_equal 2, models.size

            assert(sdf = models["versioned_model"])
            model = sdf.elements.enum_for(:each, "sdf/model").first
            assert_equal("versioned model 1.3", model.attributes["name"])
        end
    end

    describe "load_sdf" do
        it "loads a SDF file" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "simple_model", "model.sdf"))
            model = sdf.elements.enum_for(:each, "sdf/model").first
            assert_equal("simple test model", model.attributes["name"])
        end
        it "validates that the file is a XML file" do
            assert_raises(SDF::XML::InvalidXML) do
                SDF::XML.load_sdf(File.join(models_dir, "not_xml.xml"))
            end
        end
        it "validates that the file has a root" do
            assert_raises(SDF::XML::NotSDF) do
                SDF::XML.load_sdf(File.join(models_dir, "no_root.xml"))
            end
        end
        it "validates that the file is a SDF file" do
            assert_raises(SDF::XML::NotSDF) do
                SDF::XML.load_sdf(File.join(models_dir, "not_sdf.xml"))
            end
        end
        it "validates that the file exists" do
            assert_raises(Errno::ENOENT) do
                SDF::XML.load_sdf(File.join(models_dir, "does_not_exist.xml"))
            end
        end

        describe "the include tag" do
            describe "URI validation and included model validation" do
                it "raises if it does not find an uri element" do
                    full_path = File.join(invalid_models_dir, "include_without_uri",
                                          "model.sdf")
                    exception = assert_raises(SDF::XML::InvalidXML) do
                        SDF::XML.load_sdf(full_path)
                    end
                    assert_equal "while loading #{full_path}: no uri element in include",
                                 exception.message
                end
                it "raises if it the URI refers to a specific file" do
                    full_path = File.join(invalid_models_dir,
                                          "include_with_specific_file_in_uri", "model.sdf")
                    exception = assert_raises(ArgumentError) do
                        SDF::XML.load_sdf(full_path)
                    end
                    assert_equal "while loading #{full_path}: does not know how to resolve an explicit file in a model:// URI inside an include",
                                 exception.message
                end
                it "raises if it finds an unexpected element as child of the 'include' path" do
                    full_path = File.join(invalid_models_dir,
                                          "include_with_invalid_element", "model.sdf")
                    exception = assert_raises(SDF::XML::InvalidXML) do
                        SDF::XML.load_sdf(full_path)
                    end
                    assert_equal "while loading #{full_path}: unexpected element 'invalid' found as child of an include",
                                 exception.message
                end
                it "accepts relative paths as URIs, and resolve them from the SDF file's own path" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "include_relative_path", "model.sdf"))
                    assert_equal "simple test model",
                                 sdf.root.elements["//model"].attributes["name"]
                end
                it "raises if the uri is neither a model:// nor an existing directory" do
                    full_path = File.join(invalid_models_dir, "include_invalid_path",
                                          "model.sdf")
                    exception = assert_raises(ArgumentError) do
                        SDF::XML.load_sdf(full_path)
                    end
                    assert_equal "while loading #{full_path}: URI /does/not/exist is neither a model:// URI nor an existing directory",
                                 exception.message
                end
                it "raises if the included SDF has more than one model" do
                    full_path = File.join(invalid_models_dir, "include_multiple_models",
                                          "model.sdf")
                    exception = assert_raises(ArgumentError) do
                        SDF::XML.load_sdf(full_path)
                    end
                    assert_equal "while loading #{full_path}: expected included resource model://composite_model to have exactly one model",
                                 exception.message
                end

                it "resolves relative paths to a file in <uri> tags" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_with_relative_file_in_uri", "model.sdf"))
                    uri = sdf.elements.to_a("//uri").first
                    expected_full_path = File.expand_path(
                        File.join(
                            models_dir, "model_with_relative_file_in_uri", "visual.dae"
                        )
                    )
                    assert_equal(expected_full_path, uri.text)
                end
                it "resolves relative paths to other model's paths in <uri> tags" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_with_plain_model_path_in_uri", "model.sdf"))
                    uri = sdf.elements.to_a("//uri").first
                    assert_equal(File.join(models_dir, "simple_model"), uri.text)
                end
                it "properly resolves relative paths in <uri> tags from included models" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_that_includes_a_model_with_relative_paths", "model.sdf"))
                    uri = sdf.elements.to_a("//uri").first
                    expected_full_path = File.expand_path(
                        File.join(models_dir, "model_with_relative_uris", "visual.dae")
                    )
                    assert_equal(expected_full_path, uri.text)
                end
                it "resolves model:// in <uri> tags" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_with_model_uris", "model.sdf"))
                    uri = sdf.elements.to_a("//uri").first
                    assert_equal(File.join(models_dir, "simple_model", "visual.dae"),
                                 uri.text)
                end
            end

            it "reports the mapping from on-disk model path to in-SDF model path in metadata" do
                _, metadata = SDF::XML.load_sdf(
                    File.join(models_dir, "includes_at_each_level", "model.sdf"),
                    metadata: true
                )

                model_full_path = File.join(
                    models_dir, "simple_model", "model.sdf"
                )
                expected = [
                    "w::child_of_world",
                    "w::model::child_of_model",
                    "w::model::model_in_model::child_of_model_in_model",
                    "root_model::child_of_root_model",
                    "root_model::model_in_root_model::child_of_model_in_root_model"
                ]
                assert_equal [model_full_path], metadata["includes"].keys
                assert_equal expected.sort,
                             metadata["includes"][model_full_path].sort
            end

            it "properly resolves multi-level includes" do
                SDF::XML.model_path = [regressions_dir]
                _, metadata = SDF::XML.load_sdf(
                    File.join(regressions_dir, "dual_ur10.world"),
                    metadata: true
                )

                ur10_full_path = File.join(regressions_dir, "ur10", "ur10.sdf")
                dual_ur10_full_path = File.join(
                    regressions_dir, "dual_ur10", "model.sdf"
                )
                expected = Hash[
                    ur10_full_path => %w[
                        empty_world::dual_ur10_fixed::dual_ur10::left_arm
                        empty_world::dual_ur10_fixed::dual_ur10::right_arm
                    ],
                    dual_ur10_full_path => %w[empty_world::dual_ur10_fixed::dual_ur10]
                ]

                assert_equal expected, metadata["includes"]
            end

            it "handles a include tag directly under root" do
                sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                  "include_directly_under_root", "model.sdf"))
                assert sdf.elements["/sdf/model[@name='root_model']"]
            end

            describe "a toplevel model include" do
                it "adds the included model as child of a toplevel world element" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "includes_at_each_level", "model.sdf"))
                    assert sdf.elements["/sdf/world/model[@name='child_of_world']"]
                end
                it "injects the include/pose element in the included tree" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_with_new_pose_in_include", "model.sdf"))
                    model = sdf.elements.enum_for(:each, "sdf/world/model/pose").first
                    assert_equal "1 0 3 0 5 0", model.text
                end
                it "replaces an existing pose element by the include/pose element" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_that_replaces_pose_in_include", "model.sdf"))
                    model = sdf.elements.enum_for(:each, "sdf/world/model/pose").first
                    assert_equal "1 0 3 0 5 0", model.text
                end
                it "injects the include/static element in the included tree" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_with_new_static_in_include", "model.sdf"))
                    model = sdf.elements.enum_for(:each, "sdf/world/model/static").first
                    assert_equal "true", model.text
                end
                it "replaces an existing static element by the include/static element" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_that_replaces_static_in_include", "model.sdf"))
                    model = sdf.elements.enum_for(:each, "sdf/world/model/static").first
                    assert_equal "true", model.text
                end
                it "sets the name attribute on the included tree" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_that_replaces_name_in_include", "model.sdf"))
                    model = sdf.elements.enum_for(:each, "sdf/world/model").first
                    assert_equal "new_name", model.attributes["name"]
                end
            end

            describe "a model included in another model" do
                def sdf_includes_at_each_level
                    SDF::XML.load_sdf(File.join(models_dir, "includes_at_each_level",
                                                "model.sdf"))
                end

                def sdf_model_in_model_that_replaces_pose_in_include
                    SDF::XML.load_sdf(File.join(models_dir,
                                                "model_in_model_that_replaces_pose_in_include", "model.sdf"))
                end

                it "processes it if the parent model is root of a world" do
                    sdf = sdf_includes_at_each_level
                    assert sdf.elements["/sdf/world/model[@name='model']/link[@name='child_of_model::link']"]
                end
                it "processes it if the parent model is itself child of another model that is child of a world" do
                    sdf = sdf_includes_at_each_level
                    assert sdf.elements["/sdf/world/model[@name='model']/link[@name='model_in_model::child_of_model_in_model::link']"]
                end
                it "processes it if the parent model is toplevel" do
                    sdf = sdf_includes_at_each_level
                    assert sdf.elements["/sdf/model[@name='root_model']/link[@name='child_of_root_model::link']"]
                end
                it "processes it if the parent model is itself child of a toplevel model" do
                    sdf = sdf_includes_at_each_level
                    assert sdf.elements["/sdf/model[@name='root_model']/link[@name='model_in_root_model::child_of_model_in_root_model::link']"]
                end

                it "namespaces a joints parent link" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    joint_without_pose = sdf.elements[
                        'sdf/world/model/joint[@name="model_with_pose::joint_without_pose"]']
                    assert_equal "model_with_pose::link_with_pose",
                                 joint_without_pose.elements["parent"].text
                end
                it "namespaces a joints child link" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    joint_without_pose = sdf.elements[
                        'sdf/world/model/joint[@name="model_with_pose::joint_without_pose"]']
                    assert_equal "model_with_pose::link_without_pose",
                                 joint_without_pose.elements["child"].text
                end

                it "adds a pose tag to links without poses to reflect the include pose" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    link_pose = sdf.elements[
                        'sdf/world/model/link[@name="model_with_pose::link_without_pose"]/pose']
                    link_pose = SDF::Conversions.pose_to_eigen(link_pose)
                    expected_pose = SDF::Conversions.pose_to_eigen("1 0 3 0 0 0.1")
                    assert_approx_equals expected_pose, link_pose
                end
                it "does not modify the joint's poses" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    joint_pose = sdf.elements[
                        'sdf/world/model/joint[@name="model_with_pose::joint_without_pose"]/pose']
                    joint_pose = SDF::Conversions.pose_to_eigen(joint_pose)
                    expected_pose = SDF::Conversions.pose_to_eigen("0 0 0 0 0 0")
                    assert_approx_equals expected_pose, joint_pose
                end

                it "transforms a links's pose with the include pose" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    link_pose = sdf.elements[
                        'sdf/world/model/link[@name="model_with_pose::link_with_pose"]/pose']
                    link_pose = SDF::Conversions.pose_to_eigen(link_pose)
                    expected_pose = SDF::Conversions.pose_to_eigen("1 0 3 0 0 0.1") *
                                    SDF::Conversions.pose_to_eigen("1 0 1 0 0 1")
                    assert_approx_equals expected_pose, link_pose
                end

                it "does not transform a joint's pose with the include pose" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    joint_pose = sdf.elements[
                        'sdf/world/model/joint[@name="model_with_pose::joint_with_pose"]/pose']
                    joint_pose = SDF::Conversions.pose_to_eigen(joint_pose)
                    expected_pose = SDF::Conversions.pose_to_eigen("2 1 2 0 0 2")
                    assert_approx_equals expected_pose, joint_pose
                end
            end

            describe "caching" do
                it "uses the cache when loading the includes" do
                    flexmock(SDF::XML).should_receive(:model_from_name).once.pass_thru
                    SDF::XML.load_sdf(File.join(models_dir, "model_with_includes",
                                                "model.sdf"))
                end
                it "does not modify the cached included XML tree when replacing the pose" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_that_replaces_pose_in_include", "model.sdf"))
                    sdf = SDF::Root.new(sdf.root)
                    sdf = SDF::XML.model_from_name("model_with_pose", sdf.version)
                    model = sdf.elements.enum_for(:each, "sdf/model/pose").first
                    assert_equal "1 1 1 1 1 1", model.text
                end
                it "does not modify the cached included XML tree when replacing static" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_that_replaces_static_in_include", "model.sdf"))
                    sdf = SDF::Root.new(sdf.root)
                    sdf = SDF::XML.model_from_name("model_with_static", sdf.version)
                    model = sdf.elements.enum_for(:each, "sdf/model/static").first
                    assert_equal "false", model.text
                end
                it "does not modify the cached included XML tree when replacing the model name" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir,
                                                      "model_that_replaces_name_in_include", "model.sdf"))
                    sdf = SDF::Root.new(sdf.root)
                    sdf = SDF::XML.model_from_name("model_with_name", sdf.version)
                    model = sdf.elements.enum_for(:each, "sdf/model").first
                    assert_equal "name", model.attributes["name"]
                end
            end
        end
    end

    describe "model_from_name" do
        it "resolves and returns the raw model" do
            sdf = SDF::XML.model_from_name("simple_model")
            model = sdf.elements.enum_for(:each, "sdf/model").first
            assert_equal("simple test model", model.attributes["name"])
        end
        it "returns the model matching the SDF version" do
            sdf = SDF::XML.model_from_name("versioned_model", 130)
            model = sdf.elements.enum_for(:each, "sdf/model").first
            assert_equal("versioned model 1.3", model.attributes["name"])
        end
        it "caches the result" do
            sdf1 = SDF::XML.model_from_name("simple_model", flatten: false)
            sdf2 = SDF::XML.model_from_name("simple_model", flatten: false)
            assert_same sdf1, sdf2
        end
        it "caches the result in a version-aware way" do
            sdf1 = SDF::XML.model_from_name("versioned_model")
            sdf2 = SDF::XML.model_from_name("versioned_model", 130)
            model = sdf1.elements.enum_for(:each, "sdf/model").first
            assert_equal("versioned model 1.5", model.attributes["name"])
            model = sdf2.elements.enum_for(:each, "sdf/model").first
            assert_equal("versioned model 1.3", model.attributes["name"])
        end

        describe "in-memory registration and caching" do
            before do
                # Clear the gazebo models cache before each test
                SDF::XML.instance_variable_get(:@gazebo_models).clear
            end

            it "allows registering a model as a REXML::Document" do
                refute SDF::XML.cached_model("virtual_model")

                doc = REXML::Document.new("<model name='virtual'><link name='base'/></model>")
                SDF::XML.register_in_memory_model("virtual_model", doc)

                assert SDF::XML.cached_model("virtual_model")
                assert_equal doc.to_s, SDF::XML.model_from_name("virtual_model", flatten: false).to_s
            end

            it "allows registering a model as a REXML::Element" do
                refute SDF::XML.cached_model("virtual_el")

                element = REXML::Element.new("model")
                element.add_attribute("name", "virtual")
                SDF::XML.register_in_memory_model("virtual_el", element)

                assert SDF::XML.cached_model("virtual_el")
                loaded = SDF::XML.model_from_name("virtual_el", flatten: false)
                assert_equal element.to_s, loaded.root.to_s
            end

            it "allows registering a model as a raw XML String" do
                refute SDF::XML.cached_model("virtual_str")

                xml_string = "<model name='virtual'><link name='base'/></model>"
                SDF::XML.register_in_memory_model("virtual_str", xml_string)

                assert SDF::XML.cached_model("virtual_str")
                loaded = SDF::XML.model_from_name("virtual_str", flatten: false)
                assert_equal "virtual", loaded.root.attributes["name"]
            end

            it "raises ArgumentError when registering an invalid type" do
                assert_raises(ArgumentError) do
                    SDF::XML.register_in_memory_model("invalid_model", 12_345)
                end
            end

            it "falls back to the nil version cache if the requested version is not registered" do
                doc = REXML::Document.new("<model name='virtual_fallback'/>")
                # Register exclusively under nil (unversioned) cache by passing nil explicitly
                SDF::XML.register_in_memory_model("virtual_fallback", doc, sdf_version: nil)

                # Requesting with specific version 160 should fall back and load successfully
                loaded = SDF::XML.model_from_name("virtual_fallback", 160, flatten: false)
                assert_equal "virtual_fallback", loaded.root.attributes["name"]
            end

            it "resolves nested inclusions within in-memory models at registration time" do
                submodel_doc = REXML::Document.new("<sdf version='1.6'><model name='sub'><link name='sub_link'/></model></sdf>")
                SDF::XML.register_in_memory_model("submodel", submodel_doc)

                # Register a parent model containing an include to the submodel
                parent_doc = REXML::Document.new(
                    "<sdf version='1.6'>  " \
                    "<model name='parent'>    " \
                    "<include><uri>model://submodel</uri><name>included_sub</name></include>  " \
                    "</model>" \
                    "</sdf>"
                )
                resolved_doc, metadata = SDF::XML.resolve_sdf_xml(parent_doc, flatten: false, metadata: true, path: "virtual://parent_model")
                SDF::XML.register_in_memory_model("parent_model", resolved_doc, metadata: metadata)

                # Retrieve with flatten: true (which requires all inclusions to be resolved)
                loaded = SDF::XML.model_from_name("parent_model", flatten: true)

                # Verify that the submodel's links are present in the flattened parent tree
                assert loaded.elements["//link[@name='included_sub::sub_link']"]
            end
        end
        it "raises if the model cannot be found" do
            exception = assert_raises(SDF::XML::NoSuchModel) do
                SDF::XML.model_from_name("does_not_exist")
            end
            expected = /cannot find model does_not_exist in path .*. You probably want to update the GAZEBO_MODEL_PATH environment variable, or set SDF.model_path explicitely/
            assert_match expected, exception.message
        end
        it "raises if the model can be found, but not for the expected version" do
            exception = assert_raises(SDF::XML::UnavailableSDFVersionInModel) do
                SDF::XML.model_from_name("versioned_model", 100)
            end
            assert_equal "gazebo model in #{File.join(models_dir, 'versioned_model')} does not offer a SDF file matching version 100",
                         exception.message
        end
    end

    describe "flatten_model_tree" do
        def flatten_model_tree(xml)
            xml = SDF::XML.deep_copy_xml(xml)
            SDF::XML.flatten_model_tree(xml)
            xml
        end

        it "does not touch a root model" do
            xml = load_xml(<<-EOXML)
            <sdf><model name="root">
            <pose>0 1 2 3 4 5</pose>
            <link name="link" />
            </model></sdf>
            EOXML
            assert_xml_identical xml, flatten_model_tree(xml)
        end
        it "moves elements from the submodel to the parent" do
            expected = load_xml(<<-EOXML)
            <sdf><model name="root">
            <link name="link" />
            <some_element />
            </model></sdf>
            EOXML
            xml = load_xml(<<-EOXML)
            <sdf><model name="root">
            <model name="submodel"><some_element /></model>
            <link name="link" />
            </model></sdf>
            EOXML
            assert_xml_identical expected, flatten_model_tree(xml)
        end
        it "namespaces the element names" do
            expected = load_xml(<<-EOXML)
            <sdf><model name="root">
            <link name="link" />
            <some_element name="submodel::test" />
            </model></sdf>
            EOXML
            xml = load_xml(<<-EOXML)
            <sdf><model name="root">
            <model name="submodel"><some_element name="test" /></model>
            <link name="link" />
            </model></sdf>
            EOXML
            assert_xml_identical expected, flatten_model_tree(xml)
        end
        it "namespaces a joints parent and child link names" do
            expected = load_xml(<<-EOXML)
            <sdf><model name="root">
            <link name="submodel::root" />
            <link name="submodel::child" />
            <joint name="submodel::test">
            <parent>submodel::root</parent>
            <child>submodel::child</child>
            </joint>
            </model></sdf>
            EOXML
            xml = load_xml(<<-EOXML)
            <sdf><model name="root">
            <model name="submodel">
            <link name="root" />
            <link name="child" />
            <joint name="test">
            <parent>root</parent>
            <child>child</child>
            </joint>
            </model>
            </model></sdf>
            EOXML
            assert_xml_identical expected, flatten_model_tree(xml)
        end
        it "does not transform a frame element" do
            xml = load_xml(<<-EOXML)
            <sdf>
            <model name="root"><pose>1 2 3 0 0 0.1</pose>
            <model name="submodel"><pose>2 3 4 0 0 0</pose>
            <frame name="f"><pose>3 4 5 0 0 0</pose></frame>
            </model>
            </model>
            </sdf>
            EOXML
            xml = flatten_model_tree(xml)
            frame = SDF::Frame.new(xml.elements["model/frame"])
            assert_approx_equals Eigen::Vector3.new(3, 4, 5), frame.pose.translation
            assert_approx_equals Eigen::Quaternion.Identity, frame.pose.rotation
        end
        it "transforms a link element using the submodel's pose" do
            xml = load_xml(<<-EOXML)
            <sdf>
            <model name="root"><pose>1 2 3 0 0 0.1</pose>
            <model name="submodel"><pose>2 3 4 0 0 0</pose>
            <link name="f"><pose>3 4 5 0 0 0</pose></link>
            </model>
            </model>
            </sdf>
            EOXML
            xml = flatten_model_tree(xml)
            frame = SDF::Link.new(xml.elements["model/link"])
            assert_approx_equals Eigen::Vector3.new(5, 7, 9), frame.pose.translation
            assert_approx_equals Eigen::Quaternion.Identity, frame.pose.rotation
        end
        it "does not transform a joint element using the submodel's pose" do
            xml = load_xml(<<-EOXML)
            <sdf>
            <model name="root"><pose>1 2 3 0 0 0.1</pose>
            <model name="submodel"><pose>2 3 4 0 0 0</pose>
            <joint name="f"><pose>3 4 5 0 0 0</pose></joint>
            </model>
            </model>
            </sdf>
            EOXML
            xml = flatten_model_tree(xml)
            joint = SDF::Joint.new(xml.elements["model/joint"])
            assert_approx_equals Eigen::Vector3.new(3, 4, 5), joint.pose.translation
            assert_approx_equals Eigen::Quaternion.Identity, joint.pose.rotation
        end
        it "transforms a joint's axis pose using the submodel's pose if use_parent_model_frame is unset" do
            xml = load_xml(<<-EOXML)
            <sdf>
            <model name="root"><pose>1 2 3 0 0 0.1</pose>
            <model name="submodel"><pose>2 3 4 0 0 0.2</pose>
            <joint name="f">
                <pose>3 4 5 0 0 0</pose>
                <axis><xyz>0 1 2</xyz></axis>
            </joint>
            </model>
            </model>
            </sdf>
            EOXML
            xml = flatten_model_tree(xml)
            axis = SDF::Axis.new(xml.elements["model/joint/axis"])
            assert_approx_equals (Eigen::Quaternion.from_angle_axis(0.2, Eigen::Vector3.UnitZ) * Eigen::Vector3.new(0, 1, 2)),
                                 axis.xyz
        end
        it "rotates a joint's axis pose using the submodel's pose if use_parent_model_frame is set" do
            xml = load_xml(<<-EOXML)
            <sdf>
            <model name="root"><pose>1 2 3 0 0 0.1</pose>
            <model name="submodel"><pose>2 3 4 0 0 0.2</pose>
            <joint name="f">
                <pose>3 4 5 0 0 0</pose>
                <axis><xyz>0 1 2</xyz><use_parent_model_frame>true</use_parent_model_frame></axis>
            </joint>
            </model>
            </model>
            </sdf>
            EOXML
            xml = flatten_model_tree(xml)
            axis = SDF::Axis.new(xml.elements["model/joint/axis"])
            assert_approx_equals (Eigen::Quaternion.from_angle_axis(0.2, Eigen::Vector3.UnitZ) * Eigen::Vector3.new(0, 1, 2)),
                                 axis.xyz
        end
    end

    def load_xml(string)
        REXML::Document.new(string).root
    end

    def assert_xml_identical(expected, actual)
        normalized = Class.new(REXML::Formatters::Pretty) do
            def write_text(node, output)
                super(node.to_s.strip, output)
            end
        end

        normalized.new(indentation = 0, ie_hack = false)
                  .write(expected, expected_normalized = "")
        normalized.new(indentation = 0, ie_hack = false)
                  .write(actual, actual_normalized = "")

        assert_equal expected_normalized, actual_normalized
    end
end
