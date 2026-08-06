# frozen_string_literal: true

require "sdf/erb"
require "sdf/test"

describe SDF::ERB do
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
        resulting_sdf = SDF::ERB.parse_erb_as_str(erb_content, **erb_args)

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
        resulting_sdf = SDF::ERB.parse_erb_as_str(erb_content, **erb_args)

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
            SDF::ERB.parse_erb_as_str(erb_content)
        end
    end
end
