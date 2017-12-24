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
          if attachment.file_server.nil? || (options[:download].nil? && attachment.can_be_stored_on_server? )
            return link_to_attachment_without_ftp(attachment, options)
          end
          mailer_path = (options[:only_path] == false ? false : true)
          Rails.logger.debug("Mailer path #{options[:only_path]}, #{mailer_path}")

          url = attachment.file_server.ftpurl_for(attachment.disk_directory,
                                                  true, root_included=true, show_credentials=mailer_path) + "/" + attachment.disk_filename

          # RUJ : Change to Regex later. Temp fix. To manual check.
          encode_uri = if url.include?("[") || url.include?("]")
                         URI.encode(url, '[]')
                       else
                         URI.encode(url)
                       end

          uri2 = URI.parse(encode_uri)
          uri2.scheme ||= 'ftp'
          link_to(h(attachment.filename), uri2.to_s, options.merge(target: '_blank'))
        end
      end
    end
  end
end