require 'rubygems'
require 'sinatra'
require 'erb'
require 'json'
require 'pp'
require 'ostruct'
require 'open-uri'
require 'flickraw'

set :sessions, true
FlickRaw.api_key = ENV['flickr_api_key']

get '/' do
  response.headers['Cache-Control'] = 'public, max-age=300'
  erb :index
end

get '/settings' do
  @flickr_username = session['flickr_username']
  @audioboo_username = session['audioboo_username']
  erb :settings
end

post '/settings' do
  @flickr_username = params[:flickr_username]
  @audioboo_username = params[:audioboo_username]
  
  session['flickr_username'] = @flickr_username
  if @audioboo_username
    session['audioboo_username'] = @audioboo_username
    redirect "/boos/by/user/#{@audioboo_username}"
  else
    erb :settings
  end
end

get '/boos/by/user/:username' do |username|
  response.headers['Cache-Control'] = 'public, max-age=300'
  @user = $audioboo.user(username)
  @boos = $audioboo.user_boos(@user)
  erb :user
end

get '/boos/:id' do |id|
  @flickr_username = session['flickr_username']
  @audioboo_username = session['audioboo_username']
  
  @boo = $audioboo.boo(id)
  @embed_url = "http://#{request.env['HTTP_HOST']}/embed/#{@boo.id}"
  if params['photo']
    sizes = flickr.photos.getSizes(:photo_id => params['photo'])
    pp sizes
    thumbnail = sizes.find {|s| s.label == 'Thumbnail' }
    @image_url = thumbnail['source']
    @embed_url << "?photo=#{params['photo']}"
  else
    @image_url = @boo.urls['image']
  end
  erb :boo
end

get '/embed/:id' do |id|
  @boo = $audioboo.boo(id)
  if params['photo']
    sizes = flickr.photos.getSizes(:photo_id => params['photo'])
    pp sizes
    thumbnail = sizes.find {|s| s.label == 'Medium' }
    @image_url = thumbnail['source']
  else
    @image_url = @boo.urls['image']
  end
  erb :embed, :layout => false
end


OpenStruct.send(:define_method, :id) { @table[:id] }
class AudioBoo
  API = 'http://api.audioboo.fm'
  def initialize()
  end
  
  def user(username)
    data = get("/users.json?find[username]=#{username}")
    OpenStruct.new(data['users'].first)
  end
  
  def boo(id)
    data = get("/audio_clips/#{id}.json")
    OpenStruct.new(data['audio_clip'])
  end
  
  def user_boos(user)
    data = get("/users/#{user.id}/audio_clips.json")
    data['audio_clips'].map { |c| OpenStruct.new(c) }
  end
  
  protected
  
  def get(path)
    url = "#{API}#{path}"
    p url
    data = JSON.parse(open(url).read)
    data['body']
  end
end
$audioboo = AudioBoo.new
