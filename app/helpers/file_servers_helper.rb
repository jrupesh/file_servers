module FileServersHelper
  def file_server_project_options_for_select(file_server)
    projects = Project.find(:all,
                 :conditions => "file_server_id is null or file_server_id != #{file_server.id}",
                 :order => 'name')
    options_for_select(projects.collect {|p| [p.name + (p.file_server.nil? ? "" : "   (#{l(:label_file_server_current)}: #{p.file_server.name})") , p.id]})
  end
end
