module FileServers
  module Patches
    module IssuesControllerPatch
      
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          before_filter :find_issue, :only => [:show, :edit, :update, :scan_files]
          before_filter :authorize, :except => [:index, :scan_files]
          # before_filter   :scan_files, :only => :show
        end
      end

      module ClassMethods
      end

      module InstanceMethods
        def scan_files
          logger.debug("IssuesControllerPatch ---- scan_files")
          # if @issue.project.file_server && @issue.project.file_server.autoscan
          respond_to do |format|
            format.js do
              @attachments_old   = @issue.attachments
              @scan_result       = @issue.scan_alien_files(true)
              @attachments_new   = @issue.attachments - @attachments_old
              @attachments_delob = @attachments_old - @issue.attachments
              @attachments_deled = @attachments_delob.map(&:filename)
              logger.debug("IssuesControllerPatch ---- scan_files -- Deleted file IDS -- #{@attachments_deled}")
              @options           = {}
              @options.assert_valid_keys(:author, :thumbnails)
              @options = {:deletable => @issue.attachments_deletable?, :author => true}.merge(@options)
            end
            format.html { redirect_to_referer_or issue_path(@issue) }
          end
        end 
      end
    end
  end
end