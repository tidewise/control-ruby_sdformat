module SDF
    # A representation of a SDF document root
    class Root < Element
        xml_tag_name "sdf"

        # The XML document underlying this SDF document
        #
        # @return [REXML::Document]
        attr_reader :xml

        # The metadata produced while loading this root
        attr_reader :metadata

        def initialize(xml, metadata = {})
            super(xml)
            @metadata = metadata.dup
            @metadata["includes"] ||= {}
        end

        # Loads a SDF file
        #
        # @param [String] sdf_file the path to the SDF file or a model:// URI
        # @param [Integer,nil] expected_sdf_version if the SDF file is a
        #   model:// URI, this is the maximum expected SDF version (as version *
        #   100, i.e. version 1.5 is represented by 150). Leave to nil to always
        #   read the latest.
        # @raise [Errno::ENOENT] if the files does not exist
        # @raise [XML::NotSDF] if the file is not a SDF file
        # @raise [XML::InvalidXML] if the file is not a valid XML file
        # @return [Root]
        def self.load(sdf_file, expected_sdf_version = nil, flatten: true)
            if sdf_file =~ %r{^model://(.*)}
                load_from_model_name(::Regexp.last_match(1), expected_sdf_version,
                                     flatten: flatten)
            else
                xml, metadata = XML.load_sdf(sdf_file, flatten: flatten, metadata: true)
                new(xml.root, metadata)
            end
        end

        # Load a model from its name
        #
        # See {XML.find_and_load_gazebo_model}. This method raises if the model
        # cannot be found
        #
        # @param [String] model_name the model name
        # @param [Integer,nil] sdf_version the maximum expected SDF version
        #   (as version * 100, i.e. version 1.5 is represented by 150). Leave to
        #   nil to always read the latest.
        # @return [Root]
        def self.load_from_model_name(model_name, sdf_version = nil, flatten: true)
            xml, metadata = XML.model_from_name(model_name, sdf_version,
                                                flatten: flatten, metadata: true)
            new(xml.root, metadata)
        end

        # The SDF version
        #
        # @return [Integer] the advertised SDF version (as version * 100, i.e.
        #   version 1.5 is represented by 150).
        def version
            return unless version = xml.attributes["version"]

            (Float(version) * 100).round
        end

        # Returns Model objects from a given included model
        #
        # The included model can be a full path to a SDF file or a model:// URI.
        # This function will not work - and raise - on flattened SDF trees.
        #
        # @param [String] model the model, either as a full path to the SDF
        #   file, or as a model:// URI
        # @return [Array] list of included models (as Model objects) in this
        #   root that are coming from the requested model
        # @raise ArgumentError if an expected node cannot be found. This will
        #   happen on flattened SDF trees.
        def find_all_included_models(model, sdf_version = version)
            full_path = if uri_match = %r{^model://}.match(model)
                            XML.model_path_from_name(uri_match.post_match,
                                                     sdf_version: sdf_version)
                        else
                            model
                        end
            (@metadata["includes"][full_path] || []).map do |full_name|
                if element = find_by_name(full_name)
                    element
                else
                    raise ArgumentError,
                          "#{full_name}, referred to as an included element for #{full_path} does not seem to exist, is this a flattened SDF tree ?"
                end
            end
        end

        # Returns the full path to the model that provided this element
        def find_file_of(element)
            return @metadata["path"] if element == self

            name = element.full_name
            candidates = @metadata["includes"].flat_map do |file_name, root_names|
                root_names.map do |n|
                    match = (name == n) || name.start_with?("#{n}::")
                    [file_name, n] if match
                end.compact
            end

            if (match = candidates.max_by { |_, name| name.size })
                match[0]
            else
                @metadata["path"]
            end
        end

        # Enumerates the toplevel models
        #
        # @yieldparam [Model] model
        def each_model(recursive: false, &block)
            return enum_for(__method__, recursive: recursive) unless block_given?

            xml.elements.each do |element|
                if element.name == "world" && recursive
                    World.new(element, self).each_model(&block)
                elsif element.name == "model"
                    yield(Model.new(element, self))
                end
            end
        end

        # Enumerates the toplevel worlds
        #
        # @yieldparam [World] world
        def each_world
            return enum_for(__method__) unless block_given?

            xml.elements.each do |element|
                yield(World.new(element, self)) if element.name == "world"
            end
        end

        # Make a XML element into a proper SDF document by adding a root node,
        # and return the corresponding Root object
        #
        # @param [REXML::Element] element
        # @return [Root]
        def self.make(element, version = nil)
            if version && !version.respond_to?(:to_str)
                version = SDF.numeric_version_to_string(version)
            end

            root = REXML::Document.new
            root = root.add_element "sdf"
            root.add_element element
            root.attributes["version"] = version if version
            new(root)
        end
    end
end
