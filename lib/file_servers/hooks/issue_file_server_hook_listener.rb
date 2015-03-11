module FileServers
  module Hooks
		class IssueFileServerHookListener < Redmine::Hook::ViewListener
			render_on :view_issues_show_description_bottom, :partial => "issues/ftpscanbrowse"

      def view_projects_form(context = { })
        project = context[:project]
        f       = context[:form]
        s = "<p>"
        disabled = User.current.admin? ? {} : { :disabled => true }

        if Setting.plugin_file_servers["selection_on_project_creation"] == "on"
          s << f.select(:file_server_id, options_for_select(FileServer.all.collect {|p| [ p.name, p.id ] }, project.file_server_id ), {:required => true}, disabled )
        else
          s << f.select(:file_server_id, options_for_select(FileServer.all.collect {|p| [ p.name, p.id ] }, project.file_server_id ), {include_blank: true}, disabled )
        end
        s << link_to(image_tag('add.png', :style => 'vertical-align: middle;'),
              { controller: :file_servers, action: :new },
              :method => 'get',
              :title => l(:label_file_server_new),
              :tabindex => 200) if User.current.admin?
        s << "</p>"
        s.html_safe
      end
		end
  end
end