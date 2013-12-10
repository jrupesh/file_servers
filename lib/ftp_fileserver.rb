require 'file_servers/hooks/issue_hook'

require 'file_servers/patches/issue_patch'
require 'file_servers/patches/project_patch'
require 'file_servers/patches/attachment_patch'
require 'file_servers/patches/attachments_controller_patch'

module Redmine::Acts::Attachable
  module InstanceMethods
    alias_method :orig_save_attachments, :save_attachments
    
    def self.included(base)
      base.extend(ClassMethods)
    end

    def save_attachments(attachments, author=User.current)
      Attachment.set_context(self)
      orig_save_attachments(attachments, author=User.current)
    end
  end
end

ActiveRecord::Base.send(:include, Redmine::Acts::Attachable)

Project.send(:include, FileServers::Patches::ProjectPatch)
Issue.send(:include, FileServers::Patches::IssuePatch)
Attachment.send(:include, FileServers::Patches::AttachmentPatch)
AttachmentsController.send(:include, FileServers::Patches::AttachmentsControllerPatch)