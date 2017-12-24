require 'file_servers/patches/acts_as_attachable_patch'
require 'file_servers/jobs/ftp_uploader_job'

require 'file_servers/patches/attachment_patch'
require 'file_servers/patches/project_patch'
require 'file_servers/patches/application_helper_patch'
require 'file_servers/patches/issue_patch'
require 'file_servers/patches/attachments_helper_patch'
require 'file_servers/patches/issues_controller_patch'
require 'file_servers/patches/attachments_controller_patch'

ActionDispatch::Callbacks.to_prepare do
  require_dependency 'file_servers/hooks/issue_file_server_hook_listener'
end

Rails.application.configure do
  config.active_job.queue_adapter = :delayed_job

  if Rails.env.production?
    DelayedJobWeb.use Rack::Auth::Basic do |username, password|
      # authenticate
      user = User.try_to_login(username, password)
      user.present? && user.admin? ? true : false
    end
  end
end
#
# module Redmine::Acts::Attachable
#   module InstanceMethods
#     alias_method :orig_save_attachments, :save_attachments
#
#     def self.included(base)
#       base.extend(ClassMethods)
#     end
#
#     def save_attachments(attachments, author=User.current)
#       Attachment.set_context(self)
#       orig_save_attachments(attachments, author)
#     end
#   end
# end
#
Rails.configuration.to_prepare do
  # Delayed::Worker.destroy_failed_jobs = false
  # Delayed::Worker.max_run_time = 15.minutes
  Delayed::Worker.logger = Rails.logger
  Delayed::Worker.delay_jobs = !Rails.env.test?
  Delayed::Worker.sleep_delay = 60

  unless Attachment.included_modules.include? FileServers::Patches::AttachmentPatch
    Attachment.send(:include, FileServers::Patches::AttachmentPatch)
  end

  unless Project.included_modules.include? FileServers::Patches::ProjectPatch
    Project.send(:include, FileServers::Patches::ProjectPatch)
  end

  unless ApplicationHelper.included_modules.include? FileServers::Patches::ApplicationHelperPatch
    ApplicationHelper.send(:include, FileServers::Patches::ApplicationHelperPatch)
  end

  unless Redmine::Acts::Attachable::InstanceMethods.included_modules.include? FileServers::Patches::ActsAsAttachablePatch::ActsAsAttachableInstancePatch
    Redmine::Acts::Attachable::InstanceMethods.send(:include, FileServers::Patches::ActsAsAttachablePatch::ActsAsAttachableInstancePatch)
  end

  unless Issue.included_modules.include? FileServers::Patches::IssuePatch
    Issue.send(:include, FileServers::Patches::IssuePatch)
  end

  unless AttachmentsHelper.included_modules.include? FileServers::Patches::AttachmentsHelperPatch
    AttachmentsHelper.send(:include, FileServers::Patches::AttachmentsHelperPatch)
  end
  # unless Redmine::Acts::Attachable::ClassMethods.included_modules.include? FileServers::Patches::ActsAsAttachablePatch::ActsAsAttachableClassPatch
  #   Redmine::Acts::Attachable::ClassMethods.send(:include, FileServers::Patches::ActsAsAttachablePatch::ActsAsAttachableClassPatch)
  # end

  unless IssuesController.included_modules.include? FileServers::Patches::IssuesControllerPatch
    IssuesController.send(:include, FileServers::Patches::IssuesControllerPatch)
  end

  unless AttachmentsController.included_modules.include? FileServers::Patches::AttachmentsControllerPatch
    AttachmentsController.send(:include, FileServers::Patches::AttachmentsControllerPatch)
  end

  #   unless ActiveRecord::Base.included_modules.include? Redmine::Acts::Attachable
  #     ActiveRecord::Base.send(:include, Redmine::Acts::Attachable)
  #   end
end