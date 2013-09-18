require 'airbrake'
require 'sinatra/base'
require 'pivotal_tracker'
require 'active_support/all'
require 'rack/ssl-enforcer'

PivotalTracker::Client.use_ssl = true

class CardOMatic < Sinatra::Base
  configure :production do
    use Rack::SslEnforcer

    if ENV["USE_AIRBRAKE"]
      Airbrake.configure do |config|
        config.api_key = ENV["AIRBRAKE_API_KEY"]
        config.host    = ENV["AIRBRAKE_HOST"]
        config.port    = 443
        config.secure  = true
        config.params_filters << "api_key"
      end

      use Airbrake::Rack
      enable :raise_errors
    end
  end

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
      backlog = PivotalTracker::Iteration.backlog(@project)
      backlog.select {|i| i.is_a?(PivotalTracker::Iteration) }.map(&:stories).flatten
    when /\d+/
      iteration = params[:iteration].to_i

      options = { limit: 1 }
      options.merge!(offset: iteration-1) if iteration > 1

      @project.iterations.all(options).first.stories
    end

    if @stories.any?
      erb :cards, :layout => false
    else
      erb :no_cards
    end
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
    start = project.current_iteration_number < 5 ? 1 : project.current_iteration_number-4
    (start..project.current_iteration_number)
  end

  def render_previous_step_with_error(view, error)
    @error = error
    halt(400, erb(view))
  end

  class InvalidProjectId < StandardError; end
end
