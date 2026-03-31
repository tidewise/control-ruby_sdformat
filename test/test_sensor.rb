require "sdf/test"

module SDF
    describe Sensor do
        describe "#update_rate" do
            it "returns the rate as float" do
                xml = REXML::Document.new("<sensor><update_rate>22.1</update_rate></sensor>").root
                sensor = Sensor.new(xml)
                p = sensor.update_rate
                assert_in_delta 22.1, p, 1e-9
            end
            it "returns nil if the rate is not defined" do
                xml = REXML::Document.new("<sensor/>").root
                sensor = Sensor.new(xml)
                assert_nil sensor.update_rate
            end
        end

        describe "#update_period" do
            it "returns the period in seconds" do
                xml = REXML::Document.new("<sensor><update_rate>22.1</update_rate></sensor>").root
                sensor = Sensor.new(xml)
                assert_in_delta (1.0 / 22.1), sensor.update_period, 1e-6
            end
            it "returns nil if the rate is not defined" do
                xml = REXML::Document.new("<sensor/>").root
                sensor = Sensor.new(xml)
                assert_nil sensor.update_period
            end
        end

        describe "#each_plugin" do
            it "does not yield anything if the sensor has no plugin" do
                root = SDF::Sensor.new(REXML::Document.new("<sensor />").root)
                assert root.enum_for(:each_plugin).to_a.empty?
            end
            it "yields the plugins otherwise" do
                root = SDF::Sensor.new(REXML::Document.new("<sensor><plugin name=\"0\" /><plugin name=\"1\" /></sensor>").root)

                plugin = root.enum_for(:each_plugin).to_a
                assert_equal 2, plugin.size
                plugin.each do |l|
                    assert_kind_of SDF::Plugin, l
                    assert_same root, l.parent
                    assert_equal root.xml.elements.to_a("plugin[@name=\"#{l.name}\"]"), [l.xml]
                end
            end
        end
    end
end
