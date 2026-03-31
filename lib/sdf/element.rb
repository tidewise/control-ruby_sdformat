# frozen_string_literal: true

module SDF
    # Root class for all SDF elements
    #
    # This library is only wrapping the XML representation, not parsing it
    # in-place. This class provides the common API to store and access the
    # underlying XML
    class Element
        # The SDF element that is parent of this one
        #
        # @return [Element,nil] the element, or nil if self is root
        attr_reader :parent

        # The underlying XML element where information about this SDF element is
        # stored
        #
        # @return [REXML::Element]
        attr_reader :xml

        @xml_tag_name = nil

        def self.xml_tag_name(*args)
            if args.empty?
                @xml_tag_name
            else
                @xml_tag_name = args.first
            end
        end

        # @deprecated use .from_xml_string instead
        def self.from_string(string)
            from_xml_string(string)
        end

        # Create a new element
        #
        # @param [REXML::Element] xml the XML element
        # @param [Element] parent the SDF element parent of this one
        def initialize(xml = REXML::Element.new(self.class.xml_tag_name), parent = nil)
            xml_tag_name = self.class.xml_tag_name
            if xml_tag_name && xml_tag_name != xml.name
                raise ArgumentError, "expected the XML element to be " \
                                     "a '#{xml_tag_name}' tag, but got " \
                                     "#{xml.name.inspect} (#{xml})"
            end
            @xml = xml
            @parent = parent
        end

        # The element's root
        #
        # @return [Element]
        def root
            obj = self
            obj = obj.parent while obj.parent
            obj
        end

        # The model name
        #
        # @return [String]
        def name
            xml.attributes["name"]
        end

        # Change the element name
        def name=(name)
            xml.attributes["name"] = name
        end

        # The XPath from the root this element
        #
        # @return [String]
        def xpath
            xml.xpath
        end

        # Create its parent elements until the provided root element is reached
        def make_parents(root)
            xml = self.xml
            if xml.parent == root.xml
                @parent = root
            else
                @parent = self.class.wrap(xml.parent)
                parent.make_parents(root)
            end
        end

        def self.wrap(xml, parent = nil)
            xml_to_class = Hash[
                "world" => World,
                "model" => Model,
                "sdf" => Root,
                "link" => Link,
                "joint" => Joint,
                "plugin" => Plugin]

            if (klass = xml_to_class[xml.name])
                return klass.new(xml, parent)
            end

            raise NotImplementedError, "don't know how to wrap the #{xml.name} " \
                                       "XML element #{xml}"
        end

        def to_s
            s = "#{self.class.name.gsub(/.*::/, '')}[#{name}]"
            if parent
                "#{parent}/#{s}"
            else
                s
            end
        end

        # Find a named element within the SDF hierarchy
        #
        # @return [Element,nil]
        def find_by_name(name)
            xml.elements.each do |element|
                element_name = element.attributes["name"]
                return Element.wrap(element, self) if name == element_name

                if name.start_with?("#{element_name}::")
                    element = Element.wrap(element, self)
                    suffix  = name[(element_name.size + 2)..-1]
                    return element.find_by_name(suffix)
                end
            end
            nil
        end

        # Returns this element's name until the root
        #
        # The returned name stops just before the given root, i.e. with an
        # element whose complete name is
        #
        #     el0::el1::el2::element
        #
        # then
        #
        #     element.full_name(root: el1) # => "el2::element"
        #
        # @param [nil,Element] root the root until which the name is built. Use
        #   nil to stop at the XML root
        # @return [String]
        def full_name(root: nil)
            if root && xml == root.xml
                nil
            elsif (p = parent) && (p_name = p.full_name(root: root))
                p_name + "::" + name
            else
                name
            end
        end

        # @api private
        #
        # Gets one of this element's child
        #
        # @param [String] name the child's tag name
        # @param [#new(xml, parent)] klass the object that should be
        #   instanciated to represent the child
        # @param [Boolean] required if true, the method will raise if the child
        #   is not present. Otherwise, klass will be instanciated with an empty
        #   XML element
        def child_by_name(name, klass, required = true)
            children = xml.elements.to_a(name)
            if children.empty?
                if required
                    raise Invalid, "expected #{self} to have a #{name} child element, " \
                                   "but could not find one"
                end

                child = xml.add_element(name)
                klass.new(child, self)
            elsif children.size > 1
                raise Invalid, "more than one child matching #{name} found on #{self}, " \
                               "was expecting exactly one"
            else
                klass.new(children.first, self)
            end
        end

        def ==(other)
            self.class == other.class &&
                (xml == other.xml || to_xml_string == other.to_xml_string)
        end

        def eql?(other)
            self.class == other.class &&
                xml == other.xml
        end

        def hash
            xml.hash
        end

        # Create a new SDF document where self is the first element inside the
        # <sdf></sdf> element
        def make_root(flatten: false)
            # Copy the SDF version from the Root object, if there is one
            r = root
            version = r.version if r.respond_to?(:version)
            xml = self.xml.deep_clone
            XML.flatten_model_tree(xml) if flatten
            Root.make(xml, version)
        end

        def _dump(_lvl = -1)
            to_xml_string
        end

        def self._load(xml_string)
            from_xml_string(xml_string)
        end

        def self.from_xml_string(xml_string)
            new(REXML::Document.new(xml_string).root)
        end

        def to_xml_string
            xml.to_s
        end
    end
end
