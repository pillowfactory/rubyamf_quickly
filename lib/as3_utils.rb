require 'rubyamf_quickly'

module RubyAMF::Quickly
  class ActionScriptController
    attr_accessor :name, :simple_name, :actions, :package, :base_package, :ruby_class
    
    def initialize( controller_class, root_package=nil )
      self.simple_name = controller_class.to_s.split(/::/).last.gsub('Controller', '')
      self.name = "Remote#{self.simple_name}"
      self.ruby_class = controller_class
      
      # Determine this class' package
      relative_package = self.ruby_class.to_s.split(/::/)[0...-1].join('.').downcase!
      
      self.package = [root_package, relative_package].compact.join('.')
      self.base_package = [self.package, 'base'].compact.join('.')
      
      # Build methods
      self.actions = self.ruby_class.instance_methods(false).collect {|method| method.to_s}
      self.actions.sort!
    end
    
    def base_name
      return "#{self.name}Base"
    end
    
    def qualified_name
      [self.package, self.name].join('.')
    end
    
    def const_name
      self.name.dup.to_snake!.upcase
    end
  end
  
  class ActionScriptModel
    attr_accessor :name, :properties, :package, :base_package, :ruby_class
  
    def initialize( ar_class, root_package=nil )
      self.name = ar_class.to_s.split(/::/).last
      self.ruby_class = ar_class
    
      # Determine this class' package
      relative_package = ar_class.to_s.split(/::/)[0...-1].join('.').downcase!
      uncased_package = [root_package, relative_package].compact.join('.').camelize
      self.package = "#{uncased_package[0..0].downcase}#{uncased_package[1..-1]}"
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
    
    def base_name
      return "#{self.name}Base"
    end
    
    def base_class?
      return self.ruby_class.superclass == ActiveRecord::Base
    end
  end
  
  class ActionScriptProperty
    attr_accessor :name, :static_type, :accessor
    
    def initialize( ar_column )
      self.name = (RubyAMF::Configuration::ClassMappings.translate_case ? ar_column.name.dup.to_camel! : ar_column.name.dup)
      self.static_type = TypeConverter.convert(ar_column)
      self.accessor = self.name
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