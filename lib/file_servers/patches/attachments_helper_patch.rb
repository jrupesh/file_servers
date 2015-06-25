module FileServers
  module Patches
    module AttachmentsHelperPatch

      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          alias_method_chain :link_to_attachments, :ftp
        end
      end

      module InstanceMethods
      	def link_to_attachments_with_ftp(container, options = {})
          options.assert_valid_keys(:author, :thumbnails)

          attachments = container.attachments.preload(:author).to_a
          s = "".html_safe

          s << render(:partial => 'attachments/ftpscanbrowse', :locals => { :container => container }) if !%w"Message Board".include?( container.class.name )

          if attachments.any?
            options = {
              :editable => container.attachments_editable?,
              :deletable => container.attachments_deletable?,
              :author => true
            }.merge(options)
            s << render(:partial => 'attachments/links',
              :locals => {
                :container => container,
                :attachments => attachments,
                :options => options,
                :thumbnails => (options[:thumbnails] && Setting.thumbnails_enabled?)
              })
          end
          s
      	end
      end
    end
  end
end