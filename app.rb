$: << "#{File.dirname(__FILE__)}/lib"
$: << "#{File.dirname(__FILE__)}/lib/sinatra_more/lib"
$: << "#{File.dirname(__FILE__)}/lib/will_paginate/lib"
$: << "#{File.dirname(__FILE__)}/lib/rack-flash/lib"

require 'rubygems'
require 'sinatra'
require 'redcloth'
require 'openid'
require 'rack/openid'
require 'openid/store/filesystem'
require 'sinatra_more/render_plugin'
require 'sinatra_more/markup_plugin'
require 'sinatra_more/routing_plugin'
require 'sinatra_will_paginate'

require 'rack-flash.rb'

require 'slog'

include Slog

helpers WillPaginate::ViewHelpers::Base

helpers do
  
  use Rack::Session::Cookie
  use Rack::Flash
  use Rack::OpenID
  
  register SinatraMore::RoutingPlugin
  register SinatraMore::MarkupPlugin
  register SinatraMore::RenderPlugin
  
  def solr
    Slog.solr
  end
  
  # truncates a string
  # "limit" can be any number
  # adds "..." to the end if the truncated string is smaller than the original
  def trunc string, limit=10
    words = string.gsub("\n", '__nl__').split(" ")
    sections = words[0..limit]
    sections << '...' if sections.size < words.size
    truncated_string = sections.join(" ")
    truncated_string.gsub("__nl__", "\n")
  end
  
  def rc red_cloth_text
    RedCloth.new(red_cloth_text).to_html
  end
  
  def list_posts
    @solr_response = Post.find :q => params[:q], :page => params[:page], :per_page => 10
    @posts = @solr_response.docs
    erb :'posts/index'
  end
  
  def openid_consumer
    @openid_consumer ||= OpenID::Consumer.new(session, OpenID::Store::Filesystem.new("#{File.dirname(__FILE__)}/tmp/openid"))
  end
  
end

get '/sessions/new' do
  erb :'/sessions/new'
end

post '/sessions' do
  if resp = request.env["rack.openid.response"]
    puts 'response...'
    if resp.status == :success
     flash[:notice] = "Login successful!"
     redirect '/'
    else
      flash[:notice] = "Error: #{resp.status}"
      redirect '/sessions/new'
    end
  else
    www_auth_headers = Rack::OpenID.build_header(:identifier => params[:openid_url])
    headers 'WWW-Authenticate' => www_auth_headers
    throw :halt, [401, 'got openid?']
  end
end

delete '/sessions' do
  session.clear
  redirect '/'
end

# index
get '/' do
  list_posts
end

# index
get '/posts' do
  list_posts
end

# new
get '/posts/new' do
  @post = Post.new(params[:post] || {})
  erb :'posts/new'
end

# create
post '/posts' do
  doc = Post.new({})
  doc.id = Time.now.to_i
  doc.title = params[:post][:title]
  doc.body = params[:post][:body]
  solr.add doc
  solr.commit.to_s
  redirect "/posts/#{doc.id }"
end

# show
get '/posts/:id' do
  @sresponse = Post.find_by_id params[:id]
  @post = @sresponse.docs.first
  erb :'posts/show'
end

# edit
get '/posts/:id/edit' do
  @sresponse = Post.find_by_id params[:id]
  @post = @sresponse.docs.first
  erb :'posts/edit'
end

# update
put '/posts/:id' do
  @sresponse = Post.find_by_id params[:id]
  doc = @sresponse.docs.first
  doc.title = params[:post][:title]
  doc.body = params[:post][:body]
  solr.add doc
  solr.commit
  redirect "/posts/#{params[:id]}"
end

# delete
delete '/posts/:id' do
  @sresponse = Post.find_by_id params[:id]
  doc = @sresponse.docs.first
  solr.delete_by_query %(id:"#{doc.id}")
  solr.commit
  redirect "/posts"
end