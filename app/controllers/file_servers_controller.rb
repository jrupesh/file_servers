class FileServersController < ApplicationController
  unloadable

  layout 'admin'
  before_filter :require_admin

  helper :file_servers

  def index
    @file_servers = FileServer.all.order("address ASC")
  end

  def new
    @file_server = FileServer.new
    @projects = Project.all
  end

  def create
    # attrs = file_server_params
    attrs = params[:file_server]
    attrs[:password] = FileServer::crypt_password(attrs[:password])
    @file_server = FileServer.new(attrs)
    if @file_server.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'index', :tab => @file_server.class.name
    else
      render 'new'
    end
  end

  def edit
    @file_server = FileServer.find(params[:id])
    @projects = Project.all
  end

  def update
    @file_server = FileServer.find(params[:id])
    attrs = params[:file_server]
    attrs[:password] = attrs[:password] == '********' ? @file_server.password : FileServer::crypt_password(attrs[:password])
    if @file_server.update_attributes(attrs)
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'index', :tab => @file_server.class.name
      return
    end
  end

  def destroy
    @file_server = FileServer.find(params[:id]).destroy
    redirect_to :action => 'index', :tab => @file_server.class.name
  rescue
    flash[:error] = l(:error_can_not_delete_file_server)
    redirect_to :action => 'index'
  end

  # def activate_in_project
  #   file_server = FileServer.find(params[:id])
  #   project = Project.find(params[:project_id])
  #   project.file_server = file_server
  #   project.save
  #   redirect_to :action => 'edit', :id => file_server
  # end

  # def deactivate_in_project
  #   file_server = FileServer.find(params[:id])
  #   project = Project.find(params[:project_id])
  #   project.file_server = nil
  #   project.save
  #   redirect_to :action => 'edit', :id => file_server
  # end

  private
  def file_server_params
    params.require(:file_server).permit(:name, :protocol, :address, :port, :root, :login, :password, :autoscan, :is_public, :project_ids)
  end
end
