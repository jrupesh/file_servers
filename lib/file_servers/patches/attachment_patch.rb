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
          alias_method_chain  :thumbnail, :ftp
          alias_method_chain  :readable?, :ftp

          before_destroy      :delete_from_ftp
          after_save          :organize_ftp_files
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
          if Setting.plugin_file_servers["organize_uploaded_files"] == "on"
            path = get_path_from_context_project
          else
            path = target_directory_without_organize_files
          end
          logger.debug("FILESERVER : Get target directory to organize files. #{path}")
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
          if self.new_record?
            timestamp = DateTime.now.strftime("%y%m%d%H%M%S")
            self.disk_filename = "#{timestamp}_#{filename}"
          end
          logger.debug("FILESERVER : ftp filename #{self.disk_filename.blank? ? filename : self.disk_filename}")
          self.disk_filename.blank? ? filename : self.disk_filename
        end

        def ftp_relative_path(ctx = nil, pid = nil)
          return self.disk_directory if !self.disk_directory.blank?

          path = get_path_from_context_project(ctx,pid)

          if !project.nil? && project.has_file_server?
            path = project.file_server.ftpurl_for(path,false)
            project.file_server.make_directory path
          end

          self.disk_directory = path
          logger.debug("FILESERVER : ftp relative path #{path} == #{self.disk_directory}")
          self.disk_directory
        end

        def ftp_file_path(ftpn = ftp_filename, ctx = nil, pid = nil)
          ftpdirpath = ftp_relative_path(ctx, pid)
          ftpfilepath = ""
          ftpfilepath << ftpdirpath
          ftpfilepath << "/"
          ftpfilepath << ftpn
          logger.debug("FILESERVER : ftp file path #{ftpfilepath}")
          ftpfilepath
        end

        def organize_ftp_files
          logger.debug("FILESERVER : organize_ftp_files")
          (self.container && !self.container.nil?) ? context = self.container : return
          project = get_project
          return if project.nil?

          if project.has_file_server?
            logger.debug("FILESERVER : After save attachment : Project has file server.")
            f = {}
            if context.class.name == "Issue"
              path = context.alien_files_folder_url(false)

              logger.debug("FILESERVER : #{disk_filename} : #{diskfile}.")              

              if disk_filename.present? && File.exist?(diskfile)
                logger.debug("FILESERVER : After save attachment : File exists on App Server.")
                #If file exists in the local path then move to ftp.
                #This happens when calling through API.
                context.project.file_server.upload_file diskfile, path, ftp_filename
                File.delete(diskfile)
                f = { :file_server_id => project.file_server.id }
              else
                context.move_to_alien_files_folder(ftp_relative_path,path,ftp_filename)
              end
            else
              path = ftp_relative_path
            end
            content_type = Redmine::MimeType.of(filename) || "application/octet-stream" if filename.present?
            
            update_hash = {:disk_directory => path, :content_type => content_type }.merge(f)
            Attachment.update_all( update_hash ,
                                  {:id => self.id})          
            self.disk_directory = path
          elsif Setting.plugin_file_servers["organize_uploaded_issue_files"] == "on" && context.class.name == "Issue" 
            path = context.build_relative_path
            dir = File.join(self.class.storage_path, path.to_s )
            if disk_filename.present? && File.exist?(diskfile) && dir != File.dirname(self.diskfile)
              
              FileUtils.mkdir_p(dir) unless File.directory?(dir)
              FileUtils.mv(diskfile, dir) unless diskfile == File.join(dir,disk_filename)

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
          return false if self.container.nil? && self.file_server.nil?
          project = get_project
          return false if project && !project.has_file_server?
          true
        end

        def readftpcontent
          (self.file_server.nil?) ? return : fs = self.file_server
          data = nil
          if diskfile && File.exist?(diskfile)
            data = File.new(diskfile, "rb").read
          else
            fs.readftpFile("#{disk_directory}/#{disk_filename}", self.diskfile)
            data = File.new(diskfile, "rb").read
          end
          data
        end
   
        def readable_with_ftp?
          return readable_without_ftp? if self.file_server.nil?
          true
        end

        def thumbnail_with_ftp(options={})
          if thumbnailable? && !self.file_server.nil?
            size = options[:size].to_i == 0 ? Setting.thumbnails_size.to_i : options[:size].to_i
            tfile = File.join(self.class.thumbnails_storage_path, "#{id}_#{digest}_#{size}.thumb")
            if !File.exists?(tfile) && !File.exist?(self.diskfile)
              path = File.dirname(self.diskfile)
              unless File.directory?(path)
                FileUtils.mkdir_p(path)
              end              
              self.file_server.readftpFile("#{disk_directory}/#{disk_filename}", self.diskfile)
              ret = thumbnail_without_ftp(options)
              # File.delete(self.diskfile) if File.exist?(self.diskfile)
            else
              ret = thumbnail_without_ftp(options)
            end
          else
            ret = thumbnail_without_ftp(options)
          end
          ret
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