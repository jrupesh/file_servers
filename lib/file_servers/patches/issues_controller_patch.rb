module FileServers
  module Patches
    module IssuesControllerPatch

      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          before_filter :show_auto_scan_files, :only => :show
        end
      end

      module InstanceMethods
        def show_auto_scan_files
          if @issue.project.file_server && @issue.project.file_server.autoscan
            @scan_result = @issue.scan_alien_files(false)
            @issue.reload = @scan_result[:changed]
          end
        end
      end
    end
  end
end