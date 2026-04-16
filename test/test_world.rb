require "sdf/test"

module SDF
    describe World do
        describe "#each_model" do
            it "does not yield anything if the world has no models" do
                root = SDF::World.new(REXML::Document.new("<world />").root)
                assert root.enum_for(:each_model).to_a.empty?
            end
            it "yields the models otherwise" do
                root = SDF::World.new(REXML::Document.new("<world><model name=\"0\" /><model name=\"1\" /></world>").root)

                models = root.enum_for(:each_model).to_a
                assert_equal 2, models.size
                models.each do |l|
                    assert_kind_of SDF::Model, l
                    assert_same root, l.parent
                    assert_equal root.xml.elements.to_a("model[@name=\"#{l.name}\"]"),
                                 [l.xml]
                end
            end
        end
        describe "#find_model_by_name" do
            it "returns nil if the model does not exist" do
                root = SDF::World.new(REXML::Document.new("<world><model name=\"0\" /><model name=\"1\" /></world>").root)
                assert_nil root.find_model_by_name("does_not_exist")
            end
            it "yields the models otherwise" do
                xml = REXML::Document.new("<world><model name=\"0\" /><model name=\"1\" /></world>").root
                world = SDF::World.new(xml)
                assert_equal xml.elements["model[@name=\"1\"]"], world.find_model_by_name("1").xml
            end
        end
        describe ".empty" do
            it "creates a world with no models" do
                world = World.empty(name: "test")
                assert_equal "test", world.name
                assert_kind_of World, world
                assert_equal [], world.each_model.to_a
            end
        end

        describe "#spherical_coordinates" do
            it "returns the spherical coordinates object" do
                root = SDF::World.from_string("<world><spherical_coordinates><latitude_deg>0.1</latitude_deg></spherical_coordinates></world>")
                assert_in_delta 0.1, root.spherical_coordinates.latitude_deg, 1e-6
            end
            it "raises if there is no spherical coordinates element" do
                root = SDF::World.from_string("<world />")
                assert_raises(Invalid) do
                    root.spherical_coordinates
                end
            end
        end
    end
end
