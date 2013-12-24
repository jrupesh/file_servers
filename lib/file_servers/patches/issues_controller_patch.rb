module FileServers
  module Patches
    module IssuesControllerPatch
      
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          before_filter :find_issue, :only => [:show, :edit, :update, :scan_files]
        end
      end

      module ClassMethods
      end

      module InstanceMethods
        def scan_files
          logger.debug("IssuesControllerPatch ---- scan_files")
          @scan_result = @issue.scan_alien_files(true)
          link_to_attachments @issue
        end 
      end
    end
  end
end