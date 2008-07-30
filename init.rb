require File.join('app', 'controllers', 'application')
require 'rubyamf_quickly'

# Include the filter methods
ActionController::Base.send(:include, RubyAMF::Quickly::Filters)

# Add the filters to ApplicationController
ApplicationController.before_filter( :prepare_amf_params ) if RubyAMF::Quickly::Config.stuff_params
ApplicationController.rescue_from( Exception, :with => :amf_exception_handler ) if RubyAMF::Quickly::Config.convert_unhandled_exceptions