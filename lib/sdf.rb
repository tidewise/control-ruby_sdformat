require "geoutm"
require "eigen"
require "sdf/exceptions"
require "sdf/xml"
require "sdf/conversions"
require "sdf/element"
require "sdf/root"
require "sdf/physics"
require "sdf/spherical_coordinates"
require "sdf/world"
require "sdf/model"
require "sdf/link"
require "sdf/joint"
require "sdf/axis"
require "sdf/axis_limit"
require "sdf/plugin"
require "sdf/sensor"
require "sdf/frame"
require "sdf/loader"

# The toplevel namespace for sdf
#
# You should describe the basic idea about sdf here
require "utilrb/logger"

# The ruby_sdformat library is a pure-Ruby library to load and interpret [SDF
# files](http://sdformat.org)
#
# What is SDF
# -----------
# SDF is an XML format that describes objects and environments for robot
# simulators, visualization, and control. Originally developed as part of the
# Gazebo robot simulator, SDF was designed with scientific robot applications in
# mind. Over the years, SDF has become a stable, robust, and extensible format
# capable of describing all aspects of robots, static and dynamic objects,
# lighting, terrain, and even physics.
#
module SDF
    extend Logger::Root("SDF", Logger::WARN)

    # Exception raised when the XML does not match the SDF specification
    class Invalid < RuntimeError; end

    # Converts a numerical SDF version, as used in the library to a string
    # representation more suited for human consumption
    #
    # @param [Integer] v the numerical version where the hundreds represent the
    #   major version and the units the minor version
    # @return [String]
    def self.numeric_version_to_string(v)
        major = v / 100
        minor = v % 100
        minor /= 10 while minor != 0 && (minor % 10 == 0)
        "#{major}.#{minor}"
    end

    # Converts a {SDF::Element} to a XML string
    #
    # @param [SDF::Element] element the element to convert
    # @return [String] the element, represented by a marshalled XML document
    def self.to_xml(element)
        # Get the SDF version
        root = element.root
        v = numeric_version_to_string(root.version)
        "<sdf version=\"#{v}\">#{element.xml}</sdf>"
    end
end
