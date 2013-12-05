require 'project_patch'
require 'attachment_patch'
require 'attachments_controller_patch'

# module Redmine::Acts::Attachable
#   module InstanceMethods
#     alias_method :orig_save_attachments, :save_attachments
    
#     def self.included(base)
#       base.extend(ClassMethods)
#     end

#     def save_attachments(attachments, author=User.current)
#       Attachment.set_context(self)
#       orig_save_attachments(attachments, author=User.current)
#     end
    
#   end
# end

# ActiveRecord::Base.send(:include, Redmine::Acts::Attachable)

Project.send(:include, ProjectPatch)
AttachmentsController.send(:include, AttachmentsControllerPatch)
Attachment.send(:include, AttachmentPatch)