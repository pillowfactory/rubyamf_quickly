
begin
  # Make sure RubyAMF is installed.
  rubyamf_plugin = File.join( RAILS_ROOT, 'vendor', 'plugins', 'rubyamf' )
  raise 'RubyAMF not installed' unless File.exists?(rubyamf_plugin)

  # Add the quickly configuration to rubyamf_config.rb
  add_quickly_config = true
  rubyamf_config = File.join( RAILS_ROOT, 'config', 'rubyamf_config.rb')
  File.open( rubyamf_config, 'r') do |config|
    while line = config.gets
      add_quickly_config = false if line =~ /RubyAMF::Quickly::Config/
    end
  end

  if add_quickly_config
    quickly_config = 
<<-CONFIG


# ==============================
# => RubyAMF::Quickly::Config <=  
# ==============================
  require 'rubyamf_quickly'
  # => ACTIONSCRIPT GENERATION CONFIGURATION
  
  # The ./script/generate action_script_models script will generate an ActionScript class for every concrete ActiveRecord model
  # in the RAILS_ROOT/app/models directory.  

  #=> Where do you want to generate ActionScript classes?  
  # Defaults to Peter Armstrong's suggested RAILS_ROOT/app/flex
  # RubyAMF::Quickly::Config.relative_flex_root = 'app/flex/src'
  
  #=> What package should your generated ActionScript classes belong to?  
  # Defaults to no package so all ActionScript classes will be generated to RubyAMF::Quickly.relative_flex_root
  # If you specified a value of 'org.mypackage.models' and defaulted the RubyAMF::Quickly.relative_flex_root, then all would 
  # be generated to RAILS_ROOT/app/flex/org/mypacket/models.  Any namespaced ActiveRecord models will be added to sub-packages. 
  # RubyAMF::Quickly::Config.action_script_package = nil
    
  #=> What, if any ActiveRecord models should NOT have corresponding ActionScript classes generated?
  # RubyAMF::Quickly::Config.ignore_classes = [ 'Person', 'User', 'Address' ]

  # => CONTROLLERS; THE BEFORE AND AFTER
  
  #=> Stuff Params Hash
  # If set to true, then RubyAMF::Quickly expects the first RubyAMF request parameter (rubyamf_params[0]) to be a hash and will merge
  # it into the params hash for conventional Rails params access.  No need for conditional is_amf controller logic.
  # RubyAMF::Quickly::Config.stuff_params = true
  
  #=> Convert unhandled Exceptions to FaultEvents
  # If set to true, then all unhandled Ruby Exceptions will be rescued, converted to and rendered as a RubyAMF FaultObject to trigger
  # an ActionScript fault handler with the FaultEvent's fault.message set to the rescued exception's message.
  # RubyAMF::Quickly::Config.convert_unhandled_exceptions = true

  # => QUICK OPINIONS
  # The following overrides some of the above RubyAMF::Configuration settings to get things going in the most natural Rails and Flex way. 
  
  #=> Case Translations
  # Translate the case so ActionScript model properties follow ActionScript coding style.
  RubyAMF::Configuration::ClassMappings.translate_case = true
  
  #=> Assume Class Types 
  # Skip mappings. The RubyAMF::Quickly action_script_models generator creates the RemoteObject declarations.
  RubyAMF::Configuration::ClassMappings.assume_types = true
  
  #=> Don't Put Remoting Parameters into the "params" hash
  # Let RubyAMF::Quickly stuff the params for you with only the attributes you need.  
  # You may want to set it back to true if you've overridden the default RubyAMF::Quickly::Config.stuff_params to false
  RubyAMF::Configuration::ParameterMappings.always_add_to_params = false
CONFIG
      
    File.open( rubyamf_config, 'a' ) do |config|
      config.puts ""
      config.puts quickly_config
    end
  end

rescue Exception => e
  puts "ERROR INSTALLING RubyAMF::Quickly - #{e.message}"
end

