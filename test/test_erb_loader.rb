# frozen_string_literal: true

require "sdf/erb_loader"
require "sdf/test"

describe SDF::ERBLoader do
    describe "#parse_erb_as_str and #render_erb_sdf_model" do
        it "parse_erb_as_str" do
            erb_content = <<~XML
                <?xml version="1.0" ?>
                <sdf version="1.6">
                    <model name="<%= model_name %>">
                        <link name="root">
                            <sensor name="g" type="gps" />
                        </link>
                        <link name="child" />
                        <joint name="roo2child" type="revolute">
                            <parent>root</parent>
                            <child>child</child>
                            <axis>
                            </axis>
                        </joint>

                        <% gps_sensors.each do |gps| %>
                            <link name="<%= gps[:name] %>">
                                <pose><%= gps[:pose].join(' ') %></pose>
                            </link>
                            <joint name="<%= gps[:name] %>_attachment" type="fixed">
                                <parent>root</parent>
                                <child><%= gps[:name] %></child>
                            </joint>
                        <% end %>

                        <plugin name="gps_test">
                            <task model="rock_gazebo::GPSTask"/>
                        </plugin>
                    </model>
                </sdf>
            XML

            erb_args = {
                model_name: "my_model_name",
                gps_sensors: [
                    {
                        name: "gps",
                        pose: [-0.679, 0.0, 1.920, 0.0, 0.0, 0.0]
                    },
                    {
                        name: "gps2",
                        pose: [2.571, 0.044, 0.808, 0, 0, 0]
                    }
                ]
            }
            resulting_sdf = SDF::ERBLoader.parse_erb_as_str(erb_content, **erb_args)

            expected_content = <<~XML
                <?xml version="1.0" ?>
                <sdf version="1.6">
                    <model name="my_model_name">
                        <link name="root">
                            <sensor name="g" type="gps" />
                        </link>
                        <link name="child" />
                        <joint name="roo2child" type="revolute">
                            <parent>root</parent>
                            <child>child</child>
                            <axis>
                            </axis>
                        </joint>

                            <link name="gps">
                                <pose>-0.679 0.0 1.92 0.0 0.0 0.0</pose>
                            </link>
                            <joint name="gps_attachment" type="fixed">
                                <parent>root</parent>
                                <child>gps</child>
                            </joint>

                            <link name="gps2">
                                <pose>2.571 0.044 0.808 0 0 0</pose>
                            </link>
                            <joint name="gps2_attachment" type="fixed">
                                <parent>root</parent>
                                <child>gps2</child>
                            </joint>

                        <plugin name="gps_test">
                            <task model="rock_gazebo::GPSTask"/>
                        </plugin>
                    </model>
                </sdf>
            XML

            formatted_erb = resulting_sdf.gsub(/\s+/, " ").strip
            formatted_expected = expected_content.gsub(/\s+/, " ").strip

            assert_equal(formatted_expected, formatted_erb)
        end

        it "parse_erb_as_str_with_extra_unused_args" do
            erb_content = <<~XML
                <?xml version="1.0" ?>
                <sdf version="1.6">
                    <model name="<%= model_name %>">
                        <link name="root">
                            <sensor name="g" type="gps" />
                        </link>
                        <link name="child" />
                        <joint name="roo2child" type="revolute">
                            <parent>root</parent>
                            <child>child</child>
                            <axis>
                            </axis>
                        </joint>

                        <% gps_sensors.each do |gps| %>
                            <link name="<%= gps[:name] %>">
                                <pose><%= gps[:pose].join(' ') %></pose>
                            </link>
                            <joint name="<%= gps[:name] %>_attachment" type="fixed">
                                <parent>root</parent>
                                <child><%= gps[:name] %></child>
                            </joint>
                        <% end %>

                        <plugin name="gps_test">
                            <task model="rock_gazebo::GPSTask"/>
                        </plugin>
                    </model>
                </sdf>
            XML

            erb_args = {
                model_name: "my_model_name",
                gps_sensors: [
                    {
                        name: "gps",
                        pose: [-0.679, 0.0, 1.920, 0.0, 0.0, 0.0]
                    },
                    {
                        name: "gps2",
                        pose: [2.571, 0.044, 0.808, 0, 0, 0]
                    }
                ],
                random_key: "random_value",
                random_array: [1, 2, 3],
                random_hash: { key1: "value1", key2: "value2" }
            }
            resulting_sdf = SDF::ERBLoader.parse_erb_as_str(erb_content, **erb_args)

            expected_content = <<~XML
                <?xml version="1.0" ?>
                <sdf version="1.6">
                    <model name="my_model_name">
                        <link name="root">
                            <sensor name="g" type="gps" />
                        </link>
                        <link name="child" />
                        <joint name="roo2child" type="revolute">
                            <parent>root</parent>
                            <child>child</child>
                            <axis>
                            </axis>
                        </joint>

                            <link name="gps">
                                <pose>-0.679 0.0 1.92 0.0 0.0 0.0</pose>
                            </link>
                            <joint name="gps_attachment" type="fixed">
                                <parent>root</parent>
                                <child>gps</child>
                            </joint>

                            <link name="gps2">
                                <pose>2.571 0.044 0.808 0 0 0</pose>
                            </link>
                            <joint name="gps2_attachment" type="fixed">
                                <parent>root</parent>
                                <child>gps2</child>
                            </joint>

                        <plugin name="gps_test">
                            <task model="rock_gazebo::GPSTask"/>
                        </plugin>
                    </model>
                </sdf>
            XML

            formatted_erb = resulting_sdf.gsub(/\s+/, " ").strip
            formatted_expected = expected_content.gsub(/\s+/, " ").strip

            assert_equal(formatted_expected, formatted_erb)
        end

        it "parse_erb_as_str_raises_on_missing_args" do
            erb_content = "<model name='<%= model_name %>'></model>"
            # Missing :model_name in erb_args
            assert_raises(NameError) do
                SDF::ERBLoader.parse_erb_as_str(erb_content)
            end
        end
    end
    describe "#loads real file" do
        before(:all) do
            @models_dir = File.expand_path("data/models", __dir__)
            @simple_model = File.join(@models_dir, "/simple_model_erb/model.sdf.erb")
        end

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
            loader = SDF::ERBLoader.new(erb_args: erb_args)

            erb_content = loader.load_sdf_raw(@simple_model)

            assert_equal "simple_model_erb",
                         REXML::XPath.first(erb_content, "//model").attributes["name"]
            poses = REXML::XPath.match(erb_content, "//pose").map(&:text)
            assert_includes poses, "0.0 1.0 2.0 3.0 4.0 5.0"
            assert_includes poses, "6.0 7.0 8.0 9.0 0.0 1.0"
        end

        it "loads a real .sdf.erb file without args" do
            erb_content = SDF::ERBLoader.new.load_sdf_raw(@simple_model)

            assert_equal "simple_model_erb",
                         REXML::XPath.first(erb_content, "//model").attributes["name"]
            poses = REXML::XPath.match(erb_content, "//pose").map(&:text)
            assert_includes poses, "-0.679 0.0 1.92 0.0 0.0 0.0"
            assert_includes poses, "2.571 0.044 0.808 0.0 0.0 0.0"
        end

        it "validates that the file is a XML file" do
            assert_raises(SDF::XML::InvalidXML) do
                SDF::ERBLoader.new.load_sdf_raw(File.join(@models_dir, "not_xml.xml"))
            end
        end
        it "validates that the file has a root" do
            assert_raises(SDF::XML::InvalidXML) do
                SDF::ERBLoader.new.load_sdf_raw(File.join(@models_dir, "no_root.xml"))
            end
        end
        it "validates that the file is a SDF file" do
            assert_raises(SDF::XML::NotSDF) do
                SDF::ERBLoader.new.load_sdf_raw(File.join(@models_dir, "not_sdf.xml"))
            end
        end
        it "validates that the file exists" do
            assert_raises(Errno::ENOENT) do
                SDF::ERBLoader.new.load_sdf_raw(File.join(@models_dir,
                                                          "does_not_exist.xml"))
            end
        end
    end
end
