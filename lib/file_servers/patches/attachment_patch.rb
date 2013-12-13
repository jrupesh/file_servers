module FileServers
  module Patches
    module AttachmentPatch
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable

          cattr_accessor(:context_obj) { nil }
          # @@context_obj = nil

          # cattr_accessor :skip_callbacks
          # @skip_callbacks = false
          # attr_accessible :file, :author

          # after_validation :save_to_ftp
          alias_method_chain :files_to_final_location, :ftp
          before_destroy   :delete_from_ftp

          # before_update    :update_disk_directory
          after_update     :organize_ftp_files
          # after_update     lambda { organize_ftp_files }, :unless => :skip_callbacks

          # attr_accessible  :context, :project
          before_validation  :set_context_default

        end
      end

      module ClassMethods
        def set_context(context)
          @@context_obj = context
        end
        
        def get_context
          @@context_obj
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

        def set_context_default
          self.class.set_context(nil)
        end

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
          if !project.nil? && project.has_file_server? && Setting.plugin_file_servers["organize_uploaded_files"] == "on" && 
            @temp_file && (@temp_file.size > 0)

            # self.disk_filename = Attachment.disk_filename(filename) if disk_filename.blank?
            logger.debug("Uploading to #{disk_filename} --- #{self.disk_filename}")
            content = @temp_file.respond_to?(:read) ? @temp_file.read : @temp_file

            project.file_server.puttextcontent(content, ftp_file_path)

            md5 = Digest::MD5.new
            md5.update(content)
            self.digest = md5.hexdigest

            # set the temp file to nil so the model's original after_save block 
            # skips writing to the filesystem
            @temp_file = nil
          else
            files_to_final_location_without_ftp
          end
          # puts "Temp file after ftp --- #{@temp_file}"
        end

        def delete_from_ftp
          # context = self.container || self.class.get_context
          # project = context.is_a?(Hash) ? Project.find(context[:project]) : context.project if !context.nil?
          project = get_project
          if !project.nil? && project.has_file_server?
            logger.debug "[redmine_ftp_attachments] Deleting #{ftp_filename}"
            project.file_server.delete_file(ftp_file_path, ftp_filename)
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
          path << ctx

          if !project.nil? && project.has_file_server?
            path = project.file_server.url_for(path.compact.join('/'),false)
            project.file_server.make_directory path
          end

          self.disk_directory = path
        end

        def ftp_file_path(fn = ftp_filename, ctx = nil, pid = nil)
          path = ftp_relative_path(ctx, pid)
          path << "/"
          path << fn
          path
        end

        def organize_ftp_files
          (self.container && !self.container.nil?) ? context = self.container : return
          # project = context.is_a?(Hash) ? Project.find(context[:project]) : context.project if !context.nil?
          project = get_project
          if !project.nil? && context.class.name == "Issue" && project.has_file_server?
            context.move_to_alien_files_folder(ftp_relative_path,ftp_filename)
            Attachment.update_all({:disk_directory => context.alien_files_folder_url(false)},
                                  {:id => self.id})
          end
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
            if !@context.nil?
              if @context.is_a?(Hash)
                @project = Project.find(@context[:project]) if (@context.has_key?(:project) && !@context[:project].nil?)
              else
                @project = @context.project if @context.respond_to?(:project)
              end
            end
            @project
          end
      end
    end
  end
end