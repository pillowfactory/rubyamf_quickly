require 'active_support'

module RubyAMF
  module Quickly
    
    module Config
      # DESIGN TIME
      mattr_accessor :relative_flex_root
      mattr_accessor :action_script_package
      mattr_accessor :relative_model_package
      mattr_accessor :relative_controller_package
      mattr_accessor :ignore_class_names
      
      @@relative_flex_root = 'app/flex'
      @@action_script_package = nil
      @@relative_model_package = 'models'
      @@relative_controller_package = 'remoting'
      @@ignore_class_names = []

      # RUNTIME
      mattr_accessor :convert_unhandled_exceptions
      mattr_accessor :stuff_params
      
      @@convert_unhandled_exceptions = true;
      @@stuff_params = true;
    end
    
    module Filters
      # If the first parameter of the incoming params/rubyamf_params is a hash, then merge them into the params hash
      def prepare_amf_params
        if is_amf
          params_src = RubyAMF::Configuration::ParameterMappings.always_add_to_params ? params : rubyamf_params
          params.merge! params_src[0] if params_src.is_a?(Hash)
        end
      end
      
      # Convert any unhandled exception to an AMF FaultObject so it triggers a FaultEvent
      def amf_exception_handler(ex)
        RAILS_DEFAULT_LOGGER.error exception.message
        RAILS_DEFAULT_LOGGER.error exception.backtrace.join( "\n" )
        render :amf => FaultObject.new(ex.to_s) if is_amf
      end
    end
  end
end