module SDF
    class InternalError < RuntimeError; end

    module XML
        # Exception raised when trying to load a model URI, but the model does
        # not contain a SDF entry for the required SDF version
        class UnavailableSDFVersionInModel < ArgumentError; end
        # Exception raised when trying to load a file that is not a SDF file
        class NotSDF < ArgumentError; end
        # Exception raised when trying to load a malformed XML file
        class InvalidXML < ArgumentError; end

        # Exception raised when trying to resolve a model that cannot be found
        # in {model_path}
        class NoSuchModel < ArgumentError
            attr_reader :model_name

            def initialize(model_name)
                super
                @model_name = model_name
            end
        end
    end
end
