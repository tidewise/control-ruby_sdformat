# frozen_string_literal: true

require "erb"
require "sdf/erb_context"
require "sdf/test"

describe SDF::ERBContext do
    it "ERBContext makes keys available falling back to missing_methods" do
        gps_pose = [1.0, 2.0, 3.0, 0.0, 0.0, 0.0]
        gps2_pose = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        poses = {
            poses: {
                gps: gps_pose,
                gps2: gps2_pose
            }
        }
        erb_context = SDF::ERBContext.new(args: poses)

        assert_equal erb_context.poses.gps, gps_pose
        assert_equal erb_context.poses.gps2, gps2_pose
    end

    it "ERBContext correctly process defaults" do
        gps_pose = [1.0, 2.0, 3.0, 0.0, 0.0, 0.0]
        gps2_pose = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        poses = {
            poses: {
                gps: gps_pose
            }
        }
        erb_context = SDF::ERBContext.new(args: poses)

        erb_context.defaults(
            {
                poses: {
                    gps: [-0.679, 0.0, 1.920, 0.0, 0.0, 0.0],
                    gps2: gps2_pose
                }
            }
        )

        assert_equal erb_context.poses.gps, gps_pose
        assert_equal erb_context.poses.gps2, gps2_pose
    end

    it "ERBContext raises when calling a method which is not a key in erb_args" do
        gps_pose = [1.0, 2.0, 3.0, 0.0, 0.0, 0.0]
        poses = {
            poses: {
                gps: gps_pose
            }
        }
        erb_context = SDF::ERBContext.new(args: poses)

        assert_raises(SDF::ERBContext::MissingArgumentError) do
            erb_context.poses.not_defined
        end

        assert_raises(SDF::ERBContext::MissingArgumentError) do
            erb_context.not_defined
        end
    end
end
