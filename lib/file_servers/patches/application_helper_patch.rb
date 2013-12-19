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
			    # has_file_server = attachment.container.is_a?(Issue) && attachment.project.has_file_server?
			    if attachment.container.is_a?(Issue) && attachment.project.has_file_server?
			      url = attachment.container.project.file_server.url_for(attachment.disk_directory,
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