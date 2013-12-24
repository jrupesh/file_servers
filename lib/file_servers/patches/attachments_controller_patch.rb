module FileServers
  module Patches
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
          before_filter :ftp_attachment_read, :only => :show          
          before_filter :prepare_attachment_context, :except => :destroy
          skip_before_filter :file_readable
        end
      end

      module InstanceMethods
        def ftp_attachment_read
          return if !@attachment.hasfileinftp?
          logger.error "ftp_attachment_read ------."
          respond_to do |format|
            format.html {
              if @attachment.is_diff?
                @diff = @attachment.readftpcontent
                @diff_type = params[:type] || User.current.pref[:diff_type] || 'inline'
                @diff_type = 'inline' unless %w(inline sbs).include?(@diff_type)
                # Save diff type as user preference
                if User.current.logged? && @diff_type != User.current.pref[:diff_type]
                  User.current.pref[:diff_type] = @diff_type
                  User.current.preference.save
                end
                render :action => 'diff'
              elsif @attachment.is_text? && @attachment.filesize <= Setting.file_max_size_displayed.to_i.kilobyte
                @content = @attachment.readftpcontent
                render :action => 'file'
              else
                ftpdownload
              end
            }
            format.api
          end
        end

        def ftpdownload
          if @attachment.container.is_a?(Version) || @attachment.container.is_a?(Project)
            @attachment.increment_download
          end

          if stale?(:etag => @attachment.digest)
            # images are sent inline
            url = @attachment.container.project.file_server.url_for(@attachment.disk_directory,
                    true ,public=false,root_included=true) + "/" + @attachment.disk_filename

            # send_file url,  :filename => @attachment.filename,
            #                 :type => detect_content_type(@attachment),
            #                 :disposition => (@attachment.image? ? 'inline' : 'attachment')
            redirect_to url
          end
        end        
      end

      module Redmine23AndNewer
        def prepare_attachment_context
          # Ajax upload starts without the acutal attachment instance.
          # Setting the context based on the params available in the HTTP link.

          # redirecting to dropbox is not necessary only an ajax upload is being done,
          # which is determined by having an uninitialized @attachment
          # skip_redirection = false
          
          # XXX Redmine 2.3+ ajax file upload handling
          if @attachment.nil?
            # Since we uploads occur prior to an actual record being created,
            # the context needs to be parsed from the url.
            #   ex: http://url/projects/project_id/..../action_id
            req = request.env["HTTP_REFERER"]
            if req.nil?
              Attachment.set_context :class => nil, :project => nil
              Attachment.set_file_attr_accessible
            else
              ref = req.split("/")

              # logger.error "ref file link for js upload #{ref}."

              # We also only want the url parts that follow .../projects/ if possible.
              # If not, just use the standard split HTTP_REFERER
              ref = ref[ref.index("projects") + 1 .. -1] if ref.index("projects")

              # For "Issues", the url is longer than "News" or "Documents"
              klass_idx = (ref.length > 2) ? -2 : -1
              klass = ref[klass_idx].singularize.titlecase
              # For attachments in the "File" area, we want to identify
              # as a "Project" since there technically is no "File" container
              klass = "Project" if klass == "File"
              
              # Try to match an id (regardless of whether it'll be valid)
              record  = ref[-1].to_i
              project = if record > 0
                klass.constantize.find(record).project_id
              else
                ref[0] # we won't have a project AND a record, so this shouldn't fail
              end

              # filename = request.env["QUERY_STRING"].scan(/filename=(.*)/).flatten.first
              # path = Attachment.ftp_absolute_path(filename, klass, project)

              Attachment.set_context :class => klass, :project => project
              logger.debug("Attachment.set_context klass #{klass} project #{project}")
              # Attachment.set_context :class => klass, :project => project, :record => record
              # skip_redirection = true
            end
          else
            if @attachment.respond_to?(:container)
              # Attachment.set_context @attachment.container
              # increment the download counter if necessary
              @attachment.increment_download if (@attachment.container.is_a?(Version) || @attachment.container.is_a?(Project))
            end
          end
          # path ||= @attachment.ftp_file_path
          # redirect_to_dropbox(path) unless skip_redirection
        end
      end

      module Redmine22AndOlder
        def prepare_attachment_context
          if @attachment.respond_to? :container
            if (@attachment.container.is_a?(Version) || @attachment.container.is_a?(Project))
              @attachment.increment_download
            end
          end
          # redirect_to_dropbox @attachment.dropbox_path
        end
      end
    end
  end
end