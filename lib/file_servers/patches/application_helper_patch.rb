module FileServers
  module Patches
    module ApplicationHelperPatch

      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          alias_method_chain :link_to_attachment, :ftp
        end
      end

      module InstanceMethods

      	def link_to_attachment_with_ftp(attachment, options={})
			    if !attachment.file_server.nil?
			      url = attachment.file_server.ftpurl_for(attachment.disk_directory,
			      				true ,public=false,root_included=true) + "/" + attachment.disk_filename
			      link_to(h(attachment.filename), url, :target => "_blank")
			    else
			    	link_to_attachment_without_ftp(attachment, options)
			    end
      	end
      end
    end
  end
end