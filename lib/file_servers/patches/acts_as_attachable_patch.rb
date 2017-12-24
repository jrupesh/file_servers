module FileServers::Patches::ActsAsAttachablePatch
  module ActsAsAttachableInstancePatch
    def self.included(base)
      base.class_eval do
        def build_relative_path
          path = ''
          if self.class.name == 'Issue'
            i1 = (id / 10000).to_i
            i2 = (id / 100).to_i
            path  = sprintf("%.5d-%.5d",i1*10000,(i1*10000+9999)) + "/"
            path += sprintf("%.5d-%.5d",i2*100,(i2*100+99)) + "/"
            path += id.to_s
          else
            path += project.identifier
            path += if self.class.name == 'Message'
                      "/Board/#{container.board_id}"
                    elsif self.class.name == 'WikiPage'
                      "/Wiki/#{id}"
                    else
                      "/#{self.class.name}/#{id}"
                    end
          end
          logger.debug("FILESERVER : build_relative_path : #{path}")
          path
        end

        def create_alien_files_folder
          logger.debug("FILESERVER : create_alien_files_folder.")
          project.file_server.make_directory(build_relative_path) if project && project.has_file_server?
        end

        def alien_files_folder(url=false)
          return '' if project.nil? || project.file_server.nil?
          project.file_server.ftpurl_for(build_relative_path, url)
        end

        def create_scan_file_attachment(file, filesize, path)
          new_att = Attachment.new
          new_att.container      = self
          new_att.filename       = file
          new_att.disk_filename  = file
          new_att.filesize       = filesize
          new_att.content_type   = Redmine::MimeType.of(file) || "application/octet-stream"

          md5 = Digest::MD5.new
          new_att.digest         = md5.hexdigest # A dummy digest
          new_att.author         = User.current
          new_att.disk_directory = path
          new_att.file_server    = project.file_server
          new_att.instance_variable_set("@thumbnail_flag", true)
          new_att.save
          new_att
        end

        def scan_alien_files(changelog)
          result = { changed: false, new: [] }
          return result unless project.has_file_server?

          att_files = attachments.map(&:disk_filename)
          logger.debug("scan_alien_files ---- att_files - #{att_files}")

          begin
            path = alien_files_folder
            files = project.file_server.scan_directory alien_files_folder,att_files,true
            logger.debug("scan_alien_files ---- files - #{files}")
            if files.nil?
              result[:error] = l(:error_file_server_scan)
              return result
            end

            if respond_to?(:init_journal) && files.size > 0
              journal = init_journal(User.current)
            end

            files.each do |file, filesize|
              next if att_files.include? file
              new_att = create_scan_file_attachment(file, filesize, path)
              result[:changed] = true
              result[:new] << new_att if changelog

              journal.journalize_attachment(new_att, :added) unless journal.nil?
            end

            ## Comment out Automatic destroy of attachments if not found in the file server.
            attachments.each do |att|
              if !files.keys.include?(att.disk_filename) &&
                  att.file_server_id == project.file_server_id &&
                  att.disk_directory == path

                if journal.nil? && respond_to?(:init_journal)
                  journal = init_journal(User.current)
                  journal.journalize_attachment(att, :removed)
                end

                Attachment.destroy(att)
                result[:changed] = true;
              end
            end

            journal.save unless journal.nil?

          rescue Exception => e
            result[:error] = "#{l(:error_file_server_scan)} : #{e}"
          end
          result
        end
      end
    end
  end

  # module ActsAsAttachableClassPatch
  #   def self.included(base)
  #     base.include(ClassMethods)
  #     base.class_eval do
  #       alias_method_chain :acts_as_attachable, :file_server
  #     end
  #   end
  #
  #   module ClassMethods
  #     def acts_as_attachable_with_file_server(options = {})
  #       logger.info("FILESERVER : acts_as_attachable_with_file_server.")
  #       acts_as_attachable_without_file_server(options)
  #       after_create :create_alien_files_folder
  #     end
  #   end
  # end
end
