require 'sinatra/base'
require 'pivotal_tracker'
require 'active_support/core_ext/array'

PivotalTracker::Client.use_ssl = true

class CardOMatic < Sinatra::Base
  get '/' do
    erb :start
  end

  post '/projects' do
    setup_api_key

    begin
      @projects = PivotalTracker::Project.all
    rescue RestClient::Unauthorized
      @error = "We couldn't connect with your API key."
      halt(400, erb(:start))
    end

    erb :projects
  end

  post '/iterations' do
    setup_api_key
    setup_project

    @iterations = @project.iterations.all(offset: @project.current_iteration_number-2).reverse

    erb :iterations
  end

  post '/render' do
    setup_api_key
    setup_project

    if params[:iteration].nil? || params[:iteration].empty?
      @error = 'Please choose an iteration.'
      @iterations = @project.iterations.all(offset: @project.current_iteration_number-2).reverse
      halt(400, erb(:iterations))
    end

    @iteration = @project.iterations.all(offset: params[:iteration].to_i-1, limit: 1).first

    @stories = @iteration.stories

    erb :cards, :layout => false
  end

  def setup_project
    unless params[:project_id]
      @error = 'Please choose a project to print cards for.'
      @projects = PivotalTracker::Project.all

      halt(400, erb(:projects))
    end

    @project = PivotalTracker::Project.find(params[:project_id].to_i)

  rescue RestClient::ResourceNotFound
    @error = 'Please choose a project to print cards for.'
    @projects = PivotalTracker::Project.all

    halt(400, erb(:projects))
  end

  def setup_api_key
    @api_key = params[:api_key]

    if @api_key.nil? || @api_key.empty?
      @error = 'Please enter an API key.'
      halt(400, erb(:start))
    end

    PivotalTracker::Client.token = @api_key
  end
end
