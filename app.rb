require 'rubygems'
require 'bundler'

Bundler.setup

require 'sinatra'
require 'redcloth'
require 'openid'
require 'rack/openid'
require 'openid/store/filesystem'
require 'sinatra_more/render_plugin'
require 'sinatra_more/markup_plugin'
require 'sinatra_more/routing_plugin'
require 'rsolr'
require 'rsolr-ext'

$: << "#{File.dirname(__FILE__)}/lib"
$: << "#{File.dirname(__FILE__)}/lib/will_paginate/lib"
$: << "#{File.dirname(__FILE__)}/lib/rack-flash/lib"

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
  
  # This line is not needed for Rails.
  require 'digest/md5'
  
  # gravatar code originally from http://douglasfshearer.com/blog/gravatar-for-ruby-and-ruby-on-rails
  
  # Returns a Gravatar URL associated with the email parameter.
  def gravatar_url email, gravatar_options={}
    
    # Default highest rating.
    # Rating can be one of G, PG, R X.
    # If set to nil, the Gravatar default of X will be used.
    gravatar_options[:rating] ||= nil
    
    # Default size of the image.
    # If set to nil, the Gravatar default size of 80px will be used.
    gravatar_options[:size] ||= nil 
    
    # Default image url to be used when no gravatar is found
    # or when an image exceeds the rating parameter.
    gravatar_options[:default] ||= nil
     
    # Build the Gravatar url.
    grav_url = 'http://www.gravatar.com/avatar.php?'
    grav_url << "gravatar_id=#{Digest::MD5.new.update(email)}" 
    grav_url << "&rating=#{gravatar_options[:rating]}" if gravatar_options[:rating]
    grav_url << "&size=#{gravatar_options[:size]}" if gravatar_options[:size]
    grav_url << "&default=#{gravatar_options[:default]}" if gravatar_options[:default]
    grav_url
  end
  
  # Returns a Gravatar image tag associated with the email parameter.
  def gravatar email,gravatar_options={}
    # Set the img alt text.
    alt_text = 'Gravatar'
    # Sets the image sixe based on the gravatar_options.
    img_size = gravatar_options.include?(:size) ? gravatar_options[:size] : '80'
    "<img src=\"#{gravatar_url(email, gravatar_options)}\" alt=\"#{alt_text}\" height=\"#{img_size}\" width=\"#{img_size}\" />" 
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
  
  map(:root).to '/'
  map(:sessions).to '/sessions'
  map(:new_session).to '/sessions/new'
  map(:posts).to '/posts'
  map(:new_post).to '/posts/new'
  map(:edit_post).to '/posts/:id/edit'
  map(:post).to '/posts/:id'
  
end

get :new_session do
  erb :'/sessions/new'
end

post :sessions do
  if resp = request.env["rack.openid.response"]
    if resp.status == :success
     flash[:notice] = "Login successful!"
     redirect url_for(:root)
    else
      flash[:notice] = "Error: #{resp.status}"
      redirect url_for(:new_session)
    end
  else
    www_auth_headers = Rack::OpenID.build_header(:identifier => params[:openid_url])
    headers 'WWW-Authenticate' => www_auth_headers
    throw :halt, [401, 'got openid?']
  end
end

delete :sessions do
  session.clear
  redirect url_for(:root)
end

# index
get :root do
  list_posts
end

# index
get :posts do
  list_posts
end

# new
get :new_post do
  @post = Post.new(params[:post] || {})
  erb :'posts/new'
end

# create
post :posts do
  doc = Post.new(:id => Time.now.to_i, :title => params[:post][:title], :body => params[:post][:body])
  solr.add doc
  solr.commit
  redirect url_for(:post, :id => doc.id)
end

# show
get :post do
  @sresponse = Post.find_by_id params[:id]
  @post = @sresponse.docs.first
  erb :'posts/show'
end

# edit
get :edit_post do
  @sresponse = Post.find_by_id params[:id]
  @post = @sresponse.docs.first
  erb :'posts/edit'
end

# update
put :post do
  @sresponse = Post.find_by_id params[:id]
  doc = Post.new(@sresponse.docs.first.merge(:title => params[:post][:title], :body => params[:post][:body]))
  solr.add doc
  solr.commit
  redirect url_for(:post, :id => params[:id])
end

# delete
delete :post do
  @sresponse = Post.find_by_id params[:id]
  doc = @sresponse.docs.first
  solr.delete_by_query %(id:"#{doc.id}")
  solr.commit
  redirect url_for(:posts)
end