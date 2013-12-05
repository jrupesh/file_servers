module AttachmentPatch
  
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
    end
  end

  module ClassMethods
  end

  module InstanceMethods
  end
end