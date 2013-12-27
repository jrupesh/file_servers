module FileServers
  module Patches
    module AttachmentPatch
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable

          cattr_accessor   :context_obj
          # cattr_accessor(:context_obj) { nil }
          # @@context_obj = nil

          # cattr_accessor :skip_callbacks
          # @skip_callbacks = false
          # attr_accessible :file, :author

          # after_validation :save_to_ftp
          alias_method_chain :files_to_final_location, :ftp
          before_destroy   :delete_from_ftp

          # before_update    :update_disk_directory
          after_update     :organize_ftp_files
          # after_save       :organize_ftp_files
          # after_update     lambda { organize_ftp_files }, :unless => :skip_callbacks

          # attr_accessible  :context, :project
          # before_validation  :set_context_default

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

        # determine where the file would be stored without requiring an
        # attachment instance
        # def ftp_absolute_path(filename, context, project_id)
        #   ts = DateTime.now.strftime("%y%m%d%H%M%S")
        #   fn = "#{ts}_#{filename}"
          
        #   path = [nil]
        #   path << project_id
        #   path << context
        #   path << fn
        #   path.compact.join('/')

        #   project = Project.find(project_id)
        #   path = project.file_server.url_for(path,false) if project.has_file_server?
        #   path
        # end

        def set_file_attr_accessible
          attr_accessible :file
        end
      end

      module InstanceMethods

        # def set_context_default
        #   self.class.set_context(nil)
        # end

        def get_context_class_name
          context = self.container || self.class.get_context
          ctx = context.is_a?(Hash) ? context[:class] : context.class.name
          # record = context.is_a?(Hash) ? context[:record] : 0
          # XXX s/WikiPage/Wiki
          ctx = "Wiki" if ctx == "WikiPage"
          ctx
        end

        # def save_to_ftp
        def files_to_final_location_with_ftp
          # context = self.container || self.class.get_context
          # project = context.is_a?(Hash) ? Project.find(context[:project]) : context.project if !context.nil?
          project = get_project
          # puts
          # puts "---- Project #{project} ------"
          # puts "Setting #{Setting.plugin_file_servers["organize_uploaded_files"]}"

          # puts "Project has file server -- #{project.has_file_server?}" if !project.nil?

          # puts "Temp file -- #{@temp_file}"
          logger.debug("files_to_final_location_with_ftp Project #{project}")

          if !project.nil? && project.has_file_server? && Setting.plugin_file_servers["organize_uploaded_files"] == "on" && 
            @temp_file && (@temp_file.size > 0)

            # self.disk_filename = Attachment.disk_filename(filename) if disk_filename.blank?
            content = @temp_file.respond_to?(:read) ? @temp_file.read : @temp_file
            ret = project.file_server.puttextcontent(content, ftp_file_path)
            md5 = Digest::MD5.new
            md5.update(content)
            self.digest = md5.hexdigest

            # set the temp file to nil so the model's original after_save block 
            # skips writing to the filesystem
            @temp_file = nil if ret
            # self.disk_directory = ftp_relative_path
            if content_type.blank? && filename.present?
              self.content_type = Redmine::MimeType.of(filename) || "application/octet-stream"
            end
          end
          files_to_final_location_without_ftp
          # puts "Temp file after ftp --- #{@temp_file}"
        end

        def delete_from_ftp
          # context = self.container || self.class.get_context
          # project = context.is_a?(Hash) ? Project.find(context[:project]) : context.project if !context.nil?
          project = get_project
          if !project.nil? && project.has_file_server?
            logger.debug "[redmine_ftp_attachments] Deleting #{self.disk_directory}/#{ftp_filename}"
            ret = project.file_server.delete_file(self.disk_directory, ftp_filename)
          end
          puts 
        end

        def ftp_filename
          # logger.debug("ftp_file_path -- 01 disk_directory -- #{self.disk_directory}")
          if self.new_record?
            timestamp = DateTime.now.strftime("%y%m%d%H%M%S")
            self.disk_filename = "#{timestamp}_#{filename}"
          end
          # logger.debug("ftp_file_path -- 02 disk_directory -- #{self.disk_directory}")
          self.disk_filename.blank? ? filename : self.disk_filename
        end

        def ftp_relative_path(ctx = nil, pid = nil)
          return self.disk_directory if !self.disk_directory.blank?

          path = [nil]
          # path = [base] unless base.blank?

          if ctx.nil? && pid.nil?
            # context = self.container || self.class.get_context
            # project = context.is_a?(Hash) ? Project.find(context[:project]) : context.project if !context.nil?
            # ctx = context.is_a?(Hash) ? context[:class] : context.class.name
            # # record = context.is_a?(Hash) ? context[:record] : 0
            # # XXX s/WikiPage/Wiki
            # ctx = "Wiki" if ctx == "WikiPage"
            ctx = get_context_class_name
            project = get_project
            pid = project.identifier if !project.nil?
          end
          
          path << pid
          path << ctx if !ctx.nil?

          if !project.nil? && project.has_file_server?
            path = project.file_server.url_for(path.compact.join('/'),false)
            logger.debug("ftp_relative_path -- make_directory path -- #{path}")
            project.file_server.make_directory path
          end
          logger.debug "[ftp_relative_path] path #{path}"
          self.disk_directory = path
          self.disk_directory
        end

        def ftp_file_path(ftpn = ftp_filename, ctx = nil, pid = nil)
          ftpdirpath = ftp_relative_path(ctx, pid)
          ftpfilepath = ""
          ftpfilepath << ftpdirpath
          ftpfilepath << "/"
          # logger.debug("ftp_file_path -- 1 disk_directory -- #{self.disk_directory}")
          ftpfilepath << ftpn
          # logger.debug("ftp_file_path -- 2 disk_directory -- #{self.disk_directory}")
          # self.disk_directory = ftpdirpath
          # logger.debug("ftp_file_path -- 3 disk_directory -- #{self.disk_directory}")
          ftpfilepath
        end

        def organize_ftp_files
          (self.container && !self.container.nil?) ? context = self.container : return
          # project = context.is_a?(Hash) ? Project.find(context[:project]) : context.project if !context.nil?
          project = get_project
          if !project.nil? && project.has_file_server?
            if context.class.name == "Issue" 
              path = context.alien_files_folder_url(false)
              logger.debug("organize_ftp_files FTP path #{path} ---")
              if disk_filename.present? && File.exist?(diskfile)
                #If file exists in the local path then move to ftp.
                #This happens when calling through API.
                logger.debug("organize_ftp_files FTP Uploading to #{disk_filename} --- #{diskfile}")
                context.project.file_server.upload_file diskfile, path, ftp_filename
                File.delete(diskfile)
              else
                logger.debug("organize_ftp_files FTP moving to #{ftp_relative_path}/#{ftp_filename} --- #{path}/#{ftp_filename}")
                context.move_to_alien_files_folder(ftp_relative_path,path,ftp_filename)
              end
            else
              logger.debug("organize_ftp_files Setting path #{ftp_relative_path} --- #{path}/#{ftp_filename}")
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
          (self.container && !self.container.nil?) ? context = self.container : return
          context.project.file_server.ftp_file_exists?(disk_directory.to_s, disk_filename.to_s)
        end

        def hasfileinftp?
          project = get_project
          return false if project && !project.has_file_server?
          true
        end

        def readftpcontent
          (self.container && !self.container.nil?) ? context = self.container : return
          context.project.file_server.readftpFile("#{disk_directory}/#{disk_filename}")
        end
        
        # def update_disk_directory
        #   (self.container && !self.container.nil?) ? context = self.container : return
        #   if context.class.name == "Issue"
        #     Attachment.update_all({:disk_directory => context.alien_files_folder_url(true,true)},
        #                           {:id => self.id})
        #     # self.update_attributes(:skip_callbacks => true,
        #     #                        :disk_directory => context.alien_files_folder_url(true,true))
        #   end
        # end

        private
          def get_project
            return @project if !@project.nil?
            @project = nil
            @context = self.container || self.class.get_context
            logger.debug("get_project Context nil --- #{@context}")            
            if !@context.nil?
              if @context.is_a?(Hash)
                @project = Project.find(@context[:project]) if (@context.has_key?(:project) && !@context[:project].nil?)
              elsif @context.respond_to?(:project)
                # puts "Context --- #{@context.class.name}"                
                @project = @context.project
              else
                @project = @context if @context.class.name == "Project"
              end
            end
            # puts "Context Project --- #{@project}"            
            logger.debug("get_project Context Project --- #{@project}")
            @project
          end
      end
    end
  end
end