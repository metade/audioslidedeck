require 'rubygems'
require 'sinatra'
require 'erb'
require 'json'
require 'pp'
require 'ostruct'
require 'open-uri'
require 'flickraw'
require 'digest/md5'

require 'active_support/cache'
require 'active_support/cache/dalli_store'

configure do
  set :sessions, true
  FlickRaw.api_key = ENV['flickr_api_key']
  if ENV['cache'] == 'dalli'
    CACHE = ActiveSupport::Cache::DalliStore.new
  else
    CACHE = ActiveSupport::Cache::MemoryStore.new
  end
end

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
  if @flickr_username
    begin
      result = flickr.people.findByUsername(:username => @flickr_username)
      if result
        session['flickr_userid'] = result['id'] 
      else
        session['flickr_username'] = nil
      end
    rescue
      @flickr_username_error = true
    end
  end
  
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
  @flickr_userid = session['flickr_userid']
  @audioboo_username = session['audioboo_username']
  
  @boo = $audioboo.boo(id)
  @photos = get_photos(@boo, params['photos'])
  @ticks = params['ticks'] ? params.split(',') : Array.new(@photos.size, 0)
  
  @embed_url = "http://#{request.env['HTTP_HOST']}/embed/#{@boo.id}"
  
  erb :boo
end

get '/embed/:id' do |id|
  @boo = $audioboo.boo(id)
  @photos = get_photos(@boo, params['photos'])
  @ticks = params['ticks'] ? params['ticks'].split(',') : Array.new(@photos.size, 0)
  erb :embed, :layout => false
end

def get_photos(boo, photos)
  booimage = { :id => 'booimage', :thumbnail => @boo.urls['image'], :medium => @boo.urls['image'] }
  if photos
    photos.split(',').map do |photo|
      if (photo=='booimage')
        booimage
      else
        get_flickr_photo(photo)
      end
    end
  else
    [booimage]
  end
end

def get_flickr_photo(id)
  key = Digest::MD5.hexdigest(id)
  CACHE.fetch(key, :expires_in => 1.hour) do
    begin
      result = { :id => id }
      flickr.photos.getSizes(:photo_id => id).each do |size|
        result[size['label'].downcase.to_sym] = size['source']
      end
      result
    rescue => e
      puts e
      nil
    end
  end
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
