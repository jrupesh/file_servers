require 'uri'

module FileServers
  module Patches
    module ApplicationHelperPatch

      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          alias_method_chain :link_to_attachment, :ftp
        end
      end

      module InstanceMethods

      	def link_to_attachment_with_ftp(attachment, options={})
			    if !attachment.file_server.nil?
			      url = attachment.file_server.ftpurl_for(attachment.disk_directory,
			      				true ,root_included=true) + "/" + attachment.disk_filename
            uri2 = URI.parse(url)
            uri2.scheme ||= 'ftp'
			      link_to(h(attachment.filename), uri2.to_s, :target => "_blank", :class => 'icon icon-attachment' )
			    else
			    	link_to_attachment_without_ftp(attachment, options)
			    end
      	end
      end
    end
  end
end