module FileServers
  module Jobs
    FtpUploaderJob = Struct.new(:attachment_id) do
      def perform
        Rails.logger.info("FTP Processing attachment id #{attachment_id}")

        # Get FTP details from project
        # Connect and upload
        attachment = Attachment.find(attachment_id)
        orig_file = attachment.diskfile
        file_server = attachment.project.file_server
        ftp_file_path = attachment.ftp_file_path(file_server)
        ret_file_size = file_server.upload_file(attachment.diskfile, ftp_file_path, attachment.disk_filename, true)

        # Check filesize after completion with the current one on the server.
        raise('FTP Exception: Upload not complete.') unless ret_file_size == File.size(orig_file)

        # if same size,
        #     mark complete
        #       -> Update file server, and the disk path info.
        attachment.update_columns(file_server_id: file_server.id,
                                      disk_directory: ftp_file_path)
        #     else raise error. : Done in error method.
        #       -> Send mail to admin and the author on failure of upload.

        File.delete(orig_file)
      end

      def destroy_failed_jobs?
        false
      end

      def queue_name
        'ftp_attachment'
      end

      def error(job, exception)
        return unless job.attempts > 3
        Rails.logger.info("FTP Processing job #{job} : #{exception}")
        notifiy_error(job, exception)
      end

      def failure(job)
        Rails.logger.info("FTP Processing failure #{job}")
        notifiy_error(job)
      end

      def notifiy_error(job, exception=nil)
        options = {
          title: exception.nil? ? :label_ftp_upload_failure : :label_ftp_upload_error,
          message: "#{job.handler} : #{job.last_error}",
          url: { controller: 'attachments', action: 'show', id: YAML.load(job.handler)[:attachment_id] }
        }

        FtpuploadMailer.failure_notification(options).deliver
      end
    end
  end
end