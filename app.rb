require 'sinatra/base'
require 'pivotal_tracker'
require 'active_support/core_ext/array'

PivotalTracker::Client.use_ssl = true

class CardOMatic < Sinatra::Base
  get '/' do
    @intro = true

    erb :start
  end

  post '/projects' do
    setup_api_key

    begin
      @projects = PivotalTracker::Project.all
    rescue RestClient::Unauthorized
      render_previous_step_with_error(:start, "We couldn't connect with your API key.")
    end

    erb :projects
  end

  post '/iterations' do
    setup_api_key
    setup_project

    @iterations = fetch_iterations(@project)

    erb :iterations
  end

  post '/render' do
    setup_api_key
    setup_project

    if params[:iteration].nil? || params[:iteration].empty?
      @iterations = fetch_iterations(@project)
      render_previous_step_with_error(:iterations, 'Please choose an iteration.')
    end

    @stories = case params[:iteration]
    when 'icebox'
      @project.stories.all(state: "unscheduled")
    when 'backlog'
      PivotalTracker::Iteration.backlog(@project).first.stories
    when /\d+/
      @project.iterations.all(offset: params[:iteration].to_i-1, limit: 1).first.stories
    end

    erb :cards, :layout => false
  end

  def setup_project
    begin
      @project = PivotalTracker::Project.find(params[:project_id].to_i)
      raise InvalidProjectId unless @project
    rescue RestClient::ResourceNotFound
      raise InvalidProjectId
    end
  rescue InvalidProjectId
    @projects = PivotalTracker::Project.all
    render_previous_step_with_error(:projects, 'Please choose a project to print cards for.')
  end

  def setup_api_key
    @api_key = params[:api_key]

    if @api_key.nil? || @api_key.empty?
      render_previous_step_with_error(:start, 'Please enter an API key')
    end

    PivotalTracker::Client.token = @api_key
  end

  def fetch_iterations(project)
    project.iterations.all(offset: project.current_iteration_number-2).reverse
  end

  def render_previous_step_with_error(view, error)
    @error = error
    halt(400, erb(view))
  end

  class InvalidProjectId < StandardError; end
end
