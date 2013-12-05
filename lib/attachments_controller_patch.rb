module AttachmentsControllerPatch
  
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      # alias_method_chain :ftpupload, :upload
      alias_method_chain :upload, :ftpupload
    end

    if Redmine::VERSION.to_s >= "2.3"
      base.send(:include, Redmine23AndNewer)
    else
      base.send(:include, Redmine22AndOlder)
    end

    base.class_eval do
      unloadable
    end
  end

  module InstanceMethods
    def upload_with_ftpupload
      if @project && !@project.has_file_server?
        fs = @project.file_server

        puts " "
        puts "fs ===> #{fs.name}"
        puts

        # @attachment = Attachment.new(:file => request.raw_post)
        # @attachment.author = User.current
        # @attachment.filename = params[:filename].presence || Redmine::Utils.random_hex(16)
        # saved = @attachment.save
        # fs.upload_file(source_file_path, target_directory_path, target_file_name)
      else
        upload_without_ftpupload
      end
    end
  end

  module Redmine23AndNewer
  end

  module Redmine22AndOlder
  end

end