module FileServers
  module Patches
    module IssuePatch
      
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
        end
      end

      module ClassMethods
      end

      module InstanceMethods
        def build_relative_path
          i1 = (self.id / 10000).to_i
          i2 = (self.id / 100).to_i
          path  = sprintf("%.5d-%.5d",i1*10000,(i1*10000+9999)) + "/"
          path += sprintf("%.5d-%.5d",i2*100,(i2*100+99)) + "/"
          path += self.id.to_s
        end      

        def alien_files_folder_url(full,public=false)
          @path.blank? ? @path = build_relative_path : @path
          logger.debug("alien_files_folder_url @path #{@path} ---")
          self.project.file_server.ftpurl_for(@path,full,public) # if self.project # Check for console
        end

        def create_alien_files_folder
          return true unless self.project.has_file_server?
          folder_path = alien_files_folder_url(false)
          self.project.file_server.make_directory folder_path
        end

        def move_to_alien_files_folder(source_file,folder_path,file_name)
          return true unless self.project.has_file_server?
          # folder_path = alien_files_folder_url(false)
          logger.debug("move_to_alien_files_folder source_file - #{source_file},folder_path - #{folder_path}, file_name - #{file_name}")
          self.project.file_server.make_directory folder_path
          self.project.file_server.move_file_to_dir("#{source_file}/#{file_name}", "#{folder_path}/#{file_name}")
          folder_path
        end

        def scan_alien_files(changelog)
          result = {:changed => false, :new => []}
          return result if !self.project.has_file_server?

          path = alien_files_folder_url(false)
          url  = alien_files_folder_url(true)

          needs_reloading = false
          # att_files = self.attachments.collect{|a| a.filename}
          att_files = self.attachments.collect{|a| a.disk_filename}
          logger.debug("scan_alien_files ---- att_files - #{att_files}")

          begin
            files = self.project.file_server.scan_directory path,att_files,true
            if files.nil?
              result[:error] = l(:error_file_server_scan)
              return result
            end

            journal = issue_from.init_journal(User.current) if files.size > 0
            files.each do |file, filesize|
              next if att_files.include? file
              new_att = Attachment.new
              new_att.container_id   = self.id
              new_att.container_type = "Issue"
              new_att.filename       = file
              new_att.disk_filename  = file
              # new_att.filesize       = 0
              new_att.filesize       = filesize
              # new_att.content_type   = "application/octet-stream"
              new_att.content_type   = Redmine::MimeType.of(file) || "application/octet-stream"
              # new_att.digest         = 0
              md5 = Digest::MD5.new
              new_att.digest         = md5.hexdigest # A dummy digest
              # new_att.author_id      = 0
              new_att.author         = User.current
              new_att.disk_directory = path
              new_att.save
              result[:changed] = true;
              result[:new] << new_att if changelog
              
              journal.details << JournalDetail.new( :property => 'attachment', 
                                                    :prop_key => new_att.id,
                                                    :value => new_att.filename) if !journal.nil?
            end
            journal.save if !journal.nil?

            logger.debug("scan_alien_files ---- files - #{files.keys}")

            self.attachments.each do |att|
              if !files.keys.include? att.disk_filename
                Attachment.destroy(att)
                result[:changed] = true;
              end
            end
       
          rescue
            result[:error] = l(:error_file_server_scan)
          end

          self.reload if result[:changed]
          result
        end
      end
    end
  end
end