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
          alias_method_chain  :target_directory, :organize_files
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
          logger.debug("FILESERVER : Getting Context Name")
          context = self.container || self.class.get_context
          ctx = context.is_a?(Hash) ? context[:class] : context.class.name
          ctx = "Wiki" if ctx == "WikiPage"
          ctx
        end

        def files_to_final_location_with_ftp
          logger.debug("FILESERVER : Save files to Final location.")
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
            
            content_type = Redmine::MimeType.of(filename) || "application/octet-stream" if filename.present?
            assign_attributes(:content_type => content_type)
          else
            files_to_final_location_without_ftp
          end
        end

        def target_directory_with_organize_files
          logger.debug("FILESERVER : Get target directory to organize files.")
          if Setting.plugin_file_servers["organize_uploaded_files"] == "on"
            path = get_path_from_context_project
            path = path.compact.join('/') 
          else
            path = target_directory_without_organize_files
          end
          path
        end

        def get_path_from_context_project(ctx = nil, pid = nil)
          logger.debug("FILESERVER : get_path_from_context_project")
          path = [nil]

          if ctx.nil? && pid.nil?
            ctx = get_context_class_name
            project = get_project
            pid = project.identifier if !project.nil?
          end

          path << pid
          path << ctx if !ctx.nil?
          logger.debug("FILESERVER : get_path_from_context_project PATH #{path}")
          path.compact.join('/')
        end


        def delete_from_ftp
          logger.debug("FILESERVER : delete_from_ftp")
          if !self.file_server.nil? && Attachment.where("disk_filename = ? AND id <> ?", disk_filename, id).empty?
            ret = self.file_server.delete_file(self.disk_directory, ftp_filename)
          end
        end

        def ftp_filename
          logger.debug("FILESERVER : ftp_filename")
          if self.new_record?
            timestamp = DateTime.now.strftime("%y%m%d%H%M%S")
            self.disk_filename = "#{timestamp}_#{filename}"
          end
          self.disk_filename.blank? ? filename : self.disk_filename
        end

        def ftp_relative_path(ctx = nil, pid = nil)
          return self.disk_directory if !self.disk_directory.blank?
          logger.debug("FILESERVER : ftp_relative_path")

          path = get_path_from_context_project(ctx,pid)

          if !project.nil? && project.has_file_server?
            path = project.file_server.url_for(path,false)
            project.file_server.make_directory path
          end
          self.disk_directory = path
          self.disk_directory
        end

        def ftp_file_path(ftpn = ftp_filename, ctx = nil, pid = nil)
          logger.debug("FILESERVER : ftp_file_path")
          ftpdirpath = ftp_relative_path(ctx, pid)
          ftpfilepath = ""
          ftpfilepath << ftpdirpath
          ftpfilepath << "/"
          ftpfilepath << ftpn
          ftpfilepath
        end

        def organize_ftp_files
          logger.debug("FILESERVER : organize_ftp_files")
          (self.container && !self.container.nil?) ? context = self.container : return
          project = get_project
          return if project.nil?
          if project.has_file_server?
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
            content_type = Redmine::MimeType.of(filename) || "application/octet-stream" if filename.present?
            Attachment.update_all({:disk_directory => path, :content_type => content_type },
                                  {:id => self.id})          
            self.disk_directory = path
          elsif Setting.plugin_file_servers["organize_uploaded_issue_files"] == "on" && context.class.name == "Issue" 
            path = context.build_relative_path
            if disk_filename.present? && File.exist?(diskfile)
              dir = File.join(self.class.storage_path, path.to_s )
              FileUtils.mkdir_p(dir) unless File.directory?(dir)
              FileUtils.mv(diskfile, dir)

              content_type = Redmine::MimeType.of(filename) || "application/octet-stream" if filename.present?

              Attachment.update_all({:disk_directory => path, :content_type => content_type },
                                    {:id => self.id})          
              self.disk_directory = path
            end
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