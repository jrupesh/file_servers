module FileServers
  module Patches
    module AttachmentsControllerPatch

      def self.included(base) # :nodoc:

        if Redmine::VERSION.to_s >= "2.3"
          base.send(:include, Redmine23AndNewer)
        else
          base.send(:include, Redmine22AndOlder)
        end
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          before_filter :ftp_attachment_read, :only => :show
          before_filter :ftpdownload, :only => :download
          before_filter :ftpthumbnail, :only => :thumbnail
          before_filter :prepare_attachment_context, :except => :destroy
          before_filter :find_object_scan_path, :only => :scan_files

          alias_method_chain :file_readable, :ftp
        end
      end

      module InstanceMethods
        def scan_files
          logger.debug "scan_files ------. #{@path}"
          att_files = @container.attachments.pluck(:disk_filename)
          begin
            files = @project.file_server.scan_directory @path,att_files,true
            logger.debug("scan_alien_files ---- files - #{files}")
            if files.nil?
              flash[:error] = l(:error_file_server_scan)
              redirect_back_or_default home_path
              return
            end

            files.each do |file, filesize|
              next if att_files.include? file
              new_att = Attachment.new
              new_att.container_id   = @container.id
              new_att.container_type = @container.class.name
              new_att.filename       = file
              new_att.disk_filename  = file
              new_att.filesize       = filesize
              new_att.content_type   = Redmine::MimeType.of(file) || "application/octet-stream"

              md5 = Digest::MD5.new
              new_att.digest         = md5.hexdigest # A dummy digest
              new_att.author         = User.current
              new_att.disk_directory = @path
              new_att.file_server    = @project.file_server
              new_att.instance_variable_set("@thumbnail_flag", true)
              new_att.save
            end
            flash[:notice] = l(:success_file_server_scan)
          rescue
            flash[:error] = l(:error_file_server_scan)
          end
          redirect_back_or_default home_path
        end

        def file_readable_with_ftp
          if @attachment.hasfileinftp?
            # if @attachment.ftpfileexists?
            #   return true
            # else
            #   logger.error "Cannot send attachment, #{@attachment.diskfile} does not exist or is unreadable."
            #   render_404
            # end
            return true # Skipping the ftp reading.
          else
            file_readable_without_ftp
          end
        end

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
          logger.debug("Attachment has HTTP_USER_AGENT #{request.env['HTTP_USER_AGENT']}")
          return if !@attachment.hasfileinftp?
          logger.debug("Attachment has FTP File.")
          @attachment.instance_variable_set "@thumbnail_flag", true

          if @attachment.container.is_a?(Version) || @attachment.container.is_a?(Project)
            @attachment.increment_download
          end

          url = @attachment.file_server.ftpurl_for(@attachment.disk_directory,
                true ,root_included=true) + "/" + @attachment.disk_filename

          if stale?(:etag => @attachment.digest)
            if request.env['HTTP_USER_AGENT'] =~ /[^\(]*[^\)]Edge\//
              # images are sent inline
              send_data @attachment.readftpcontent, :filename => filename_for_content_disposition(@attachment.filename),
                                      :type => detect_content_type(@attachment),
                                      :disposition => disposition(@attachment)
            else
              redirect_to url
            end
          end
        end

        def ftpthumbnail
          logger.debug("ftpthumbnail.")
          if @attachment.hasfileinftp?
            logger.debug("ftpthumbnail : File is stored in FTP.")
            @attachment.instance_variable_set "@thumbnail_flag", true
            if @attachment.thumbnailable? && thumbnail = @attachment.ftp_thumbnail(:size => params[:size])
              if stale?(:etag => thumbnail)
                send_file thumbnail,
                  :filename => filename_for_content_disposition(@attachment.filename),
                  :type => detect_content_type(@attachment),
                  :disposition => 'inline'
              end
            else
              # No thumbnail for the attachment or thumbnail could not be created
              render :nothing => true, :status => 404
            end
          end
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

          if !@container.respond_to?(:project)
            render_403
            return
          end
          @project = @container.project
          @path = Attachment.object_scan_path(@container)
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
              # Attachment.set_file_attr_accessible
            else
              ref = req.gsub(/\?(.*)/, "").split("/")
              logger.debug("Reference Link : #{ref}")
              # logger.error "ref file link for js upload #{ref}."
              ref.delete("edit") if ref[-1] == 'edit'

              # We also only want the url parts that follow .../projects/ if possible.
              # If not, just use the standard split HTTP_REFERER
              ref = ref[ref.index("projects") + 1 .. -1] if ref.index("projects")
              logger.debug("Reference Link : #{ref}")

              # For "Issues", the url is longer than "News" or "Documents"
              klass_idx = (ref.length > 2) ? -2 : -1
              logger.debug("Reference klass_idx : #{klass_idx}")

              klass = ref[klass_idx].singularize.titlecase
              # For attachments in the "File" area, we want to identify
              # as a "Project" since there technically is no "File" container
              klass = "Project" if klass == "File"
              if klass == "Topic"
                klass = "Message"
                record  = ref[-3].to_i
                object = if record > 0
                  "Board".constantize.find(record)
                else
                  ref[0] # we won't have a project AND a record, so this shouldn't fail
                end
              else
                # Try to match an id (regardless of whether it'll be valid)
                record  = ref[-1].to_i
                object = if record > 0
                  klass.constantize.find(record)
                else
                  ref[0] # we won't have a project AND a record, so this shouldn't fail
                end
              end
              # filename = request.env["QUERY_STRING"].scan(/filename=(.*)/).flatten.first
              # path = Attachment.ftp_absolute_path(filename, klass, project)

              Attachment.set_context :class => klass, :object => object
              logger.debug("Attachment.set_context klass #{klass} object #{object}")
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