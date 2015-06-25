require 'file_servers/patches/issue_patch'
require 'file_servers/patches/project_patch'
require 'file_servers/patches/attachment_patch'

require 'file_servers/patches/issues_controller_patch'
require 'file_servers/patches/attachments_controller_patch'

require 'file_servers/patches/application_helper_patch'

ActionDispatch::Callbacks.to_prepare do
  require_dependency 'file_servers/hooks/issue_file_server_hook_listener'
end

module Redmine::Acts::Attachable
  module InstanceMethods
    alias_method :orig_save_attachments, :save_attachments

    def self.included(base)
      base.extend(ClassMethods)
    end

    def save_attachments(attachments, author=User.current)
      Attachment.set_context(self)
      orig_save_attachments(attachments, author)
    end
  end
end

Rails.configuration.to_prepare do

  unless ActiveRecord::Base.included_modules.include? Redmine::Acts::Attachable
    ActiveRecord::Base.send(:include, Redmine::Acts::Attachable)
  end

  unless Project.included_modules.include? FileServers::Patches::ProjectPatch
    Project.send(:include, FileServers::Patches::ProjectPatch)
  end

  unless Issue.included_modules.include? FileServers::Patches::IssuePatch
    Issue.send(:include, FileServers::Patches::IssuePatch)
  end

  unless Attachment.included_modules.include? FileServers::Patches::AttachmentPatch
    Attachment.send(:include, FileServers::Patches::AttachmentPatch)
  end

  unless IssuesController.included_modules.include? FileServers::Patches::IssuesControllerPatch
    IssuesController.send(:include, FileServers::Patches::IssuesControllerPatch)
  end

  unless AttachmentsController.included_modules.include? FileServers::Patches::AttachmentsControllerPatch
    AttachmentsController.send(:include, FileServers::Patches::AttachmentsControllerPatch)
  end

  unless ApplicationHelper.included_modules.include? FileServers::Patches::ApplicationHelperPatch
    ApplicationHelper.send(:include, FileServers::Patches::ApplicationHelperPatch)
  end

  unless AttachmentsHelper.included_modules.include? FileServers::Patches::AttachmentsHelperPatch
    AttachmentsHelper.send(:include, FileServers::Patches::AttachmentsHelperPatch)
  end
end