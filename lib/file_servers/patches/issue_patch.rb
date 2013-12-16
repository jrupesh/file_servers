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
          # puts "This should be initiated only once."
          # build relative path for self
          i1 = (self.id / 10000).to_i
          i2 = (self.id / 100).to_i
          path  = sprintf("%.5d-%.5d",i1*10000,(i1*10000+9999)) + "/"
          path += sprintf("%.5d-%.5d",i2*100,(i2*100+99)) + "/"
          path += self.id.to_s
        end      

        def alien_files_folder_url(full,public=false)
          @path.blank? ? @path = build_relative_path : @path
          self.project.file_server.url_for(@path,full,public) if self.project # Check for console
        end

        def create_alien_files_folder
          return true unless self.project.has_file_server?
          folder_path = alien_files_folder_url(false)
          self.project.file_server.make_directory folder_path
        end

        def move_to_alien_files_folder(source_file,folder_path,file_name)
          return true unless self.project.has_file_server?
          # folder_path = alien_files_folder_url(false)
          self.project.file_server.make_directory folder_path
          self.project.file_server.move_file_to_dir(source_file, "#{folder_path}/#{file_name}")
          folder_path
        end

        def scan_alien_files(changelog)
          result = {:changed => false, :new => []}
          return result if !self.project.has_file_server?

          path = alien_files_folder_url(false)
          url  = alien_files_folder_url(true)

          needs_reloading = false
          att_files = self.attachments.collect{|a| a.filename}
          begin
            files = self.project.file_server.scan_directory path,true
            if files.nil?
              result[:error] = l(:error_file_server_scan)
              return result
            end

            files.each do |file|
              next if att_files.include? file
              new_att = Attachment.new
              new_att.container_id   = self.id
              new_att.container_type = "Issue"
              new_att.filename       = file
              new_att.disk_filename  = file
              new_att.filesize       = 0
              new_att.content_type   = "application/octet-stream"
              new_att.digest         = 0
              new_att.author_id      = 0
              new_att.save
              result[:changed] = true;
              result[:new] << new_att if changelog
            end

            self.attachments.each do |att|
              if !files.include? att.filename
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