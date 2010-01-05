require 'rubygems'
require 'sinatra'
require 'lib/slog'

include Slog

helpers do
  
  def solr
    Slog.solr
  end
  
  def list_posts
    @solr_response = Post.find :q => params[:q]
    @posts = @solr_response.docs
    erb :'posts/index'
  end
  
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