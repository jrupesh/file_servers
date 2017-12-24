module FileServers
  module Patches
    module AttachmentsControllerPatch

      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          before_filter :find_object_scan_path, :only => :scan_files

          alias_method_chain :file_readable, :ftp
        end
      end

      module InstanceMethods
        def scan_files
          logger.debug "scan_files ------. #{@container}"
          @attachments_old   = @container.attachments
          @scan_result       = @container.scan_alien_files(true)
          @container.reload if @scan_result[:changed]
          @attachments_new   = @container.attachments - @attachments_old
          @attachments_delob = @attachments_old - @container.attachments
          @attachments_deled = @attachments_delob.map(&:filename)
          @options           = {
              :editable => @container.attachments_editable?,
              :deletable => @container.attachments_deletable?,
              :author => true
          }
          respond_to do |format|
            format.js {}
            format.html { redirect_back_or_default home_path }
          end
        end

        def file_readable_with_ftp
          if @attachment.file_server && !File.readable?(@attachment.diskfile)
            # And check the stuff
            if @attachment.can_be_stored_on_server?
              @attachment.ftp_store_content
            else
              ftpdownload
            end
          else
            file_readable_without_ftp
          end
        end

        def ftpdownload
          if @attachment.container.is_a?(Version) || @attachment.container.is_a?(Project)
            @attachment.increment_download
          end

          url = @attachment.file_server.ftpurl_for(@attachment.disk_directory,
                                                   true, root_included=true) + "/" + @attachment.disk_filename
          redirect_to url
        end

        private
        def find_object_scan_path
          klass = params[:object_type].to_s.singularize.classify.constantize rescue nil
          unless klass && klass.reflect_on_association(:attachments)
            render_404
            return
          end

          @container = klass.find(params[:object_id])
          if @container.respond_to?(:visible?) && !@container.visible?
            render_403
            return
          end

          unless @container.respond_to?(:project)
            render_403
            return
          end
          @project = @container.project

          unless @project.has_file_server?
            render_403
            return
          end
        end
      end
    end
  end
end