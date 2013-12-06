module AttachmentsControllerPatch
  
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    if Redmine::VERSION.to_s >= "2.3"
      base.send(:include, Redmine23AndNewer)
    else
      base.send(:include, Redmine22AndOlder)
    end

    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
    end
  end

  module InstanceMethods
  end

  module Redmine23AndNewer
  end

  module Redmine22AndOlder
  end

end