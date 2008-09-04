require 'app/configuration'
require 'rubyamf_quickly'
require 'as3_utils'

class ActionScriptGenerator < Rails::Generator::Base
  include RubyAMF::Quickly
  
  default_options :skip_models => false,
                  :skip_controllers => false,
                  :force_all => false
                  
  attr_accessor :skip_or_force
      
  # runtime_args[0] = AS3 base package
  def initialize(*runtime_args)
    super(*runtime_args)
    
    Config.action_script_package = runtime_args[0] unless runtime_args[0].empty?      
    self.skip_or_force = options[:force_all] ? :force : :skip
  end

  def manifest
    record do |m|
            
      # MODELS
      self.generate_models(m) unless options[:skip_models]
      
      # CONTROLLERS
      self.generate_controllers(m) unless options[:skip_controllers]
    end
  end

  protected
    
  def banner
     "Usage: #{$0} #{spec.name} actionscript.root.package [options]"
  end
  
  def add_options!(opt)
    opt.separator ''
    opt.separator 'Options:'
    opt.on("--skip-models", "Skip ActionScript model class generation") {|v| options[:skip_models] = v }
    opt.on("--skip-controllers", "Skip ActionScript controller class generation") {|v| options[:skip_controllers] = v }
    opt.on("--force-all", "Force generation of all files. WARNING: This will overwrite any changes made to previously generated files.") {|v| options[:force_all] = v }
  end
    
  def generate_controllers(m)
    controllers_package = [Config.action_script_package, Config.relative_controller_package].compact.join('.')
    controllers_root_dir = convert_package( controllers_package )
    
    # Remoting Helpers
    FileUtils.makedirs(remoting_helpers_dir = convert_package([controllers_package, 'helpers'].join('.')))
    
    m.template( "helper/as3_helper_rubyamf.erb", File.join(remoting_helpers_dir, 'RubyAMF.as'), 
                :collision => self.skip_or_force,
                :assigns => { :package => (remoting_helpers_package = [controllers_package, 'helpers'].join('.')) })
        
    # RemoteBase
    api_package = [controllers_package, 'api'].join('.')
    
    FileUtils.makedirs(controllers_api_base_dir = File.join( convert_package(api_package), 'base'))
    m.template( 'controller/as3_base.erb', File.join(controllers_api_base_dir, 'RemoteBase.as'), 
                :collision => self.skip_or_force,
                :assigns => { :package => api_package,
                              :helper_package => remoting_helpers_package })
    
    # Remoting APIs
    controllers = 
      Dir.chdir(File.join(RAILS_ROOT, 'app', 'controllers')) do
        parse_ruby :package => api_package,
                   :file_matcher => lambda{|entry| entry[-14..-1].eql? '_controller.rb' },
                   :class_matcher => lambda{|controller_class| controller_class < ApplicationController },
                   :exclude_class_names => Config.ignore_class_names
      end
    
    as3_controllers = controllers.collect do |controller, package|
      as3_class = ActionScriptController.new(controller, package)
      
      dest_dir = convert_package(as3_class.package)
      FileUtils.makedirs(base_dest_dir = File.join( dest_dir, 'base'))
              
      m.template( 'controller/as3_controller_base.erb', File.join(base_dest_dir, "#{as3_class.name}Base.as"), 
                  :collision => :force,
                  :assigns => { :as3_class => as3_class, 
                                :use_helpers => true,
                                :helper_package => remoting_helpers_package,
                                :base_class_package => api_package } )
      m.template( 'controller/as3_controller.erb', File.join(dest_dir, "#{as3_class.name}.as"), 
                  :collision => self.skip_or_force,
                  :assigns => { :as3_class => as3_class } )
                  
      as3_class
    end
    
    # Remote.as
    m.template( 'controller/as3_remote.erb', File.join(controllers_root_dir, 'Remote.as'),
                  :collision => :force,
                  :assigns => { :package => controllers_package,
                                :controllers => as3_controllers.sort {|a, b| a.qualified_name <=> b.qualified_name} } )    
  end
    
  def generate_models(m)
    models_package = [Config.action_script_package, Config.relative_model_package].compact.join('.')
    
    # Models Helpers
    models_helper_package = [models_package, 'helpers'].join('.')
    FileUtils.makedirs(models_helper_dir = convert_package(models_helper_package))
    
    ['Hash', 'Errors'].each do |helper_name|
      m.template( "helper/as3_helper_#{helper_name.downcase}.erb", File.join( models_helper_dir, "#{helper_name}.as" ), 
                  :collision => self.skip_or_force,
                  :assigns => {:package => models_helper_package })
    end
    
    # Base
    FileUtils.makedirs(base_dir = File.join(convert_package(models_package), 'base'))
    m.template( 'model/as3_base.erb', File.join(base_dir, 'Base.as'), :collision => self.skip_or_force,
                :assigns => {:package => models_package})
    
    as3_classes = {}
    (Dir.chdir(File.join(RAILS_ROOT, 'app', 'models')) do
      parse_ruby :package => models_package,
                 :file_matcher => lambda{|entry| File.extname( entry ).eql? '.rb' },
                 :class_matcher => lambda{|model_class| model_class < ActiveRecord::Base && !model_class.abstract_class? },
                 :exclude_class_names => Config.ignore_class_names
    end).each {|ar, package| as3_classes[ar] = ActionScriptModel.new(ar, package) }

    as3_classes.each do |ar, as3_class|       
      dest_dir = convert_package(as3_class.package)
      FileUtils.makedirs(base_dest_dir = File.join( dest_dir, 'base'))

      as3_superclass = as3_classes[as3_class.ruby_class.superclass]
      
      m.template( 'model/as3_model.erb', File.join(dest_dir, "#{as3_class.name}.as"), 
                  :collision => self.skip_or_force,
                  :assigns => { :as3_class => as3_class,
                                :as3_superclass_name => as3_superclass ? as3_superclass.name : "#{as3_class.name}Base",
                                :as3_superclass_package => as3_superclass ? as3_superclass.package : as3_class.base_package })      
                  
      if as3_class.base_class?
        m.template( 'model/as3_model_base.erb', File.join(base_dest_dir, "#{as3_class.name}Base.as"), 
                    :collision => :force,
                    :assigns => { :as3_class => as3_class, 
                                  :use_helpers => true,
                                  :helper_package => models_helper_package,
                                  :base_class_package => models_package } )
      end
                                
    end
  end
  
  private
  
  def convert_package(package, fully_qualified=true)
    return File.join( (fully_qualified ? Config.relative_flex_root : nil), package.to_s.split('.').compact )
  end
    
  def parse_ruby( options )
    config = { :package => '',
               :file_matcher => lambda{|entry| true },
               :class_matcher => lambda{|ruby_class| true },
               :exclude_class_names => [],
               :results => {} }.merge!(options)
    
    Dir["*"].each do |entry|
      if File.directory?(entry) && !['.','..'].include?(entry)
        Dir.chdir(entry) do
          parse_ruby(config.merge(:package => [config[:package], entry].join('.')))
        end
      elsif config[:file_matcher].call(entry)
        ruby_class_name = entry.sub(/\.rb$/, '').camelize
        unless config[:exclude_class_names].detect {|class_name| class_name === ruby_class_name }
          ruby_class = ruby_class_name.constantize
          config[:results][ruby_class] = config[:package] if config[:class_matcher].call(ruby_class)
        end
      end
    end
    
    return config[:results]
  end
end