module FileServers
  module Patches
    module AttachmentPatch
      def self.included(base) # :nodoc:
        # base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          base.const_set('FOLDER_FILESIZE', 1)

          belongs_to :file_server

          after_commit :upload_to_ftp, on: [:create, :update], if:
              proc { |attachment|
                attachment.project.present? &&
                  attachment.project.has_file_server? &&
                  attachment.file_server.nil?
              }

          after_commit :organize_files, on: [:create, :update], if:
              proc { |attachment|
                Setting.plugin_file_servers['organize_uploaded_issue_files'] == 'on' &&
                  attachment.container.present? && attachment.file_server.nil? &&
                  attachment.disk_directory != attachment.container.build_relative_path
              }

          alias_method_chain  :delete_from_disk, :ftp
        end
      end

      module InstanceMethods
        def upload_to_ftp
          logger.info('Upload to FTP.')
          Delayed::Job.enqueue FileServers::Jobs::FtpUploaderJob.new(id)
        end

        # Get the FTP folder path from attachment.
        def ftp_file_path(fserver = file_server)
          # Get container ftp path
          relative_path = container.build_relative_path
          # Build path from FTP server.
          path = fserver.ftpurl_for(relative_path, false)
          logger.debug("FILESERVER : ftp_file_path : #{path}")
          path
        end

        def delete_from_ftp!
          logger.debug("FILESERVER : delete_from_ftp")
          file_server.delete_file(disk_directory, disk_filename) if file_server
        end

        def delete_from_disk_with_ftp
          if file_server.present?
            if Attachment.where("disk_filename = ? AND id <> ?", disk_filename, id).empty?
              delete_from_disk!
              delete_from_ftp!
            end
          else
            delete_from_disk_without_ftp
          end
        end

        def organize_files
          return if container.nil?
          relative_path = container.build_relative_path
          path = File.join(self.class.storage_path, relative_path)
          FileUtils.mkdir_p(path) unless File.directory?(path)
          FileUtils.mv(diskfile, path)
          update_column :disk_directory, relative_path
        end

        def can_be_stored_on_server?
          is_diff? || (is_text? &&
              filesize <= Setting.file_max_size_displayed.to_i.kilobyte) || is_image?
        end

        def ftp_store_content
          return unless file_server.present?
          unless File.exist?(diskfile)
            logger.debug("Downloading File : #{disk_directory}/#{disk_filename} to --> #{diskfile}")
            FileUtils.mkdir_p(File.dirname(diskfile)) unless File.directory?(File.dirname(diskfile))
            file_server.readftpFile("#{disk_directory}/#{disk_filename}", diskfile)
          end
        end
      end
    end
  end
end