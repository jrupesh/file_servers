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

            # RUJ : Change to Regex later. Temp fix. To manuall check.
            if url.include?("[") || url.include?("]")
              encode_uri = URI.encode(url, '[]')
            else
              encode_uri = URI.encode(url)
            end

            uri2 = URI.parse(encode_uri)
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