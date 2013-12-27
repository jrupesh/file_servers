module FileServers
  module Patches
		class IssueFileServerHookListener < Redmine::Hook::ViewListener
			render_on :view_issues_show_description_bottom, :partial => "issues/ftpscanbrowse"
		end
  end
end