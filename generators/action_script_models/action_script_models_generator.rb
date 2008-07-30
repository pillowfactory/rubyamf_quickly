require 'app/configuration'
require 'rubyamf_quickly'

class ActionScriptModelsGenerator < Rails::Generator::Base
  include RubyAMF::Quickly
  
  default_options :skip_helpers => false, :force_all => false
      
  # runtime_args[0] = AS3 Package
  def initialize(*runtime_args)
    super(*runtime_args)
    Config.action_script_package = runtime_args[0] unless runtime_args[0].empty?      
  end

  def manifest
    record do |m|
      
      helper_package = [Config.action_script_package, 'helpers'].compact.join('.')
      skip_or_force = options[:force_all] ? :force : :skip
      
      # HELPERS
      unless options[:skip_helpers]
        FileUtils.makedirs(helper_dir = File.join(Config.relative_flex_root, helper_package.split(/\./)))
        
        ['Hash', 'RubyAMF', 'Errors'].each do |helper_name|
          m.template( "as3_helper_#{helper_name.downcase}.erb", File.join( helper_dir, "#{helper_name}.as" ), :collision => skip_or_force,
                      :assigns => {:package => helper_package })
        end
      end
      
      # MODELS
 
      # Base
      FileUtils.makedirs(base_dir = File.join(Config.relative_flex_root, Config.action_script_package.to_s.split(/\./), 'base'))
      m.template( 'as3_base.erb', File.join(base_dir, 'Base.as'), :collision => skip_or_force,
                    :assigns => {:package => [Config.action_script_package, 'base'].compact.join('.')} )
      
      ar_models = []
      Dir.chdir(File.join(RAILS_ROOT, 'app', 'models')) do 
          Dir["**/*.rb"].each do |entry|
            unless Config.ignore_classes.include?( model_class_name = entry.sub(/\.rb$/,'').camelize )
              model_class = model_class_name.constantize
              ar_models << model_class if model_class < ActiveRecord::Base && !model_class.abstract_class?
            end
          end
      end

      ar_models.each do |ar| 
        as3_class = ActionScriptModel.new( ar, Config.action_script_package )
        
        FileUtils.makedirs(dest_dir = File.join(Config.relative_flex_root, as3_class.package.to_s.split(/\./)))
        FileUtils.makedirs(base_dest_dir = File.join( dest_dir, 'base'))
                
        m.template( 'as3_model_base.erb', File.join(base_dest_dir, "#{as3_class.name}Base.as"), :collision => :force,
                    :assigns => { :as3_class => as3_class, 
                                  :use_helpers => !options[:skip_helpers],
                                  :helper_package => helper_package } )
        m.template( 'as3_model.erb', File.join(dest_dir, "#{as3_class.name}.as"), :collision => skip_or_force,
                    :assigns => { :as3_class => as3_class } )
      end
      
    end
  end

  protected
    
  def banner
     "Usage: #{$0} #{spec.name} actionscript.root.package [options]"
  end
  
  def add_options!(opt)
    opt.separator ''
    opt.separator 'Options:'
    opt.on("--skip-helpers",
           "Skip ActionScript helper classes that add simple remoting and Ruby/Rails style model behavior.") { |v| options[:skip_helpers] = v }
    opt.on("--force-all",
           "Force generation of all files. WARNING: This will overwrite any changes made to previously generated files.") { |v| options[:force_all] = v }
  end
  
end

module RubyAMF::Quickly
  class ActionScriptModel
    attr_accessor :name, :properties, :package, :base_package, :ruby_class
  
    def initialize( ar_class, root_package=nil )
      self.name = ar_class.to_s.split(/::/).last
      self.ruby_class = ar_class
    
      # Determine this class' package
      relative_package = ar_class.to_s.split(/::/)[0...-1].join('.').downcase!
      self.package = [root_package, relative_package].compact.join('.')
      self.base_package = [self.package, 'base'].compact.join('.')
    
      # Build properties
      self.properties = []
      ar_class.columns.each do |col|
        unless RubyAMF::Configuration::ClassMappings.ignore_fields.include? col.name
          self.properties << ActionScriptProperty.new(col)
        end
      end
    
      self.properties.sort! {|a, b| a.name <=> b.name }
    end
  end
  
  class ActionScriptProperty
    attr_accessor :name, :static_type, :accessor
    
    def initialize( ar_column )
      self.name = (RubyAMF::Configuration::ClassMappings.translate_case ? ar_column.name.dup.to_camel! : ar_column.name.dup)
      self.static_type = TypeConverter.convert(ar_column)
      self.accessor = (self.static_type == 'Boolean' && RubyAMF::Quickly::Config.prefix_booleans ? "is#{self.name.capitalize}" : self.name)
    end

  end

  class TypeConverter
    def self.convert( ar_col )
      ruby_class, col_type = ar_col.klass, ar_col.type
      if ruby_class == String or ruby_class < String
        return 'String'
      elsif ruby_class < Numeric
        return 'Number'
      elsif ruby_class == Object and ar_col.type == :boolean
        return 'Boolean'
      elsif ruby_class == Time or ruby_class == Date or ruby_class < Date or ruby_class < Time
        return 'Date'
      else
        return 'Object'
      end
    end
  end
end

