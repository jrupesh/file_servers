module FileServers
  module Patches
    module AttachmentPatch
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          belongs_to          :file_server
          cattr_accessor      :context_obj
          alias_method_chain  :files_to_final_location, :ftp
          before_destroy      :delete_from_ftp
          after_update        :organize_ftp_files
        end
      end

      module ClassMethods
        def set_context(context)
          @@context_obj = context
        end
        
        def get_context
          begin
            ctx = @@context_obj
          rescue
            ctx = nil
          end
          ctx
        end

        def set_file_attr_accessible
          attr_accessible :file
        end
      end

      module InstanceMethods

        def get_context_class_name
          context = self.container || self.class.get_context
          ctx = context.is_a?(Hash) ? context[:class] : context.class.name
          ctx = "Wiki" if ctx == "WikiPage"
          ctx
        end

        def files_to_final_location_with_ftp
          project = get_project

          if !project.nil? && project.has_file_server? && Setting.plugin_file_servers["organize_uploaded_files"] == "on" && 
            @temp_file && (@temp_file.size > 0)

            self.file_server = project.file_server

            content = @temp_file.respond_to?(:read) ? @temp_file.read : @temp_file
            ret = project.file_server.puttextcontent(content, ftp_file_path)

            md5 = Digest::MD5.new
            md5.update(content)
            self.digest = md5.hexdigest

            # set the temp file to nil so the model's original after_save block 
            # skips writing to the filesystem
            @temp_file = nil if ret
            self.content_type = Redmine::MimeType.of(filename) || "application/octet-stream" if filename.present?
          else
            files_to_final_location_without_ftp
          end
        end

        def delete_from_ftp
          if !self.file_server.nil? && Attachment.where("disk_filename = ? AND id <> ?", disk_filename, id).empty?
            ret = self.file_server.delete_file(self.disk_directory, ftp_filename)
          end
        end

        def ftp_filename
          if self.new_record?
            timestamp = DateTime.now.strftime("%y%m%d%H%M%S")
            self.disk_filename = "#{timestamp}_#{filename}"
          end
          self.disk_filename.blank? ? filename : self.disk_filename
        end

        def ftp_relative_path(ctx = nil, pid = nil)
          return self.disk_directory if !self.disk_directory.blank?

          path = [nil]
          if ctx.nil? && pid.nil?
            ctx = get_context_class_name
            project = get_project
            pid = project.identifier if !project.nil?
          end
          
          path << pid
          path << ctx if !ctx.nil?

          if !project.nil? && project.has_file_server?
            path = project.file_server.url_for(path.compact.join('/'),false)
            project.file_server.make_directory path
          end
          self.disk_directory = path
          self.disk_directory
        end

        def ftp_file_path(ftpn = ftp_filename, ctx = nil, pid = nil)
          ftpdirpath = ftp_relative_path(ctx, pid)
          ftpfilepath = ""
          ftpfilepath << ftpdirpath
          ftpfilepath << "/"
          ftpfilepath << ftpn
          ftpfilepath
        end

        def organize_ftp_files
          (self.container && !self.container.nil?) ? context = self.container : return
          project = get_project
          if !project.nil? && project.has_file_server?
            if context.class.name == "Issue" 
              path = context.alien_files_folder_url(false)
              if disk_filename.present? && File.exist?(diskfile)
                #If file exists in the local path then move to ftp.
                #This happens when calling through API.
                context.project.file_server.upload_file diskfile, path, ftp_filename
                File.delete(diskfile)
              else
                context.move_to_alien_files_folder(ftp_relative_path,path,ftp_filename)
              end
            else
              path = ftp_relative_path
            end
            Attachment.update_all({:disk_directory => path},
                                  {:id => self.id})          
            self.disk_directory = path
          end
        end

        def ftpdiskfile
          File.join(disk_directory.to_s, disk_filename.to_s)
        end

        def ftpfileexists?
          (self.file_server.nil?) ? return : fs = self.file_server
          fs.ftp_file_exists?(disk_directory.to_s, disk_filename.to_s)
        end

        def hasfileinftp?
          project = get_project
          return false if project && !project.has_file_server?
          true
        end

        def readftpcontent
          (self.file_server.nil?) ? return : fs = self.file_server
          fs.readftpFile("#{disk_directory}/#{disk_filename}")
        end
        
        private
          def get_project
            return @project if !@project.nil?
            @project = nil
            @context = self.container || self.class.get_context
            if !@context.nil?
              if @context.is_a?(Hash)
                @project = Project.find(@context[:project]) if (@context.has_key?(:project) && !@context[:project].nil?)
              elsif @context.respond_to?(:project)
                @project = @context.project
              else
                @project = @context if @context.class.name == "Project"
              end
            end
            @project
          end
      end
    end
  end
end