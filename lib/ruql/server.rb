require 'fileutils'

class Server
  attr_accessor :quizzes
  
  def initialize(quizzes)
    @quizzes = quizzes
  end
  
  def make_server
    make_directories
    make_gemfile
    make_gemfile_lock
    make_app_rb
    make_config_ru
    #create_repository
    #deploy
    #$stderr.puts @quizzes[0].data
  end
  
  def make_directories
    FileUtils::cd('../')
    FileUtils::mkdir_p 'app/views'
  end
  
  def make_app_rb
    content = %q{require 'sinatra/base'

class MyApp < Sinatra::Base
  
  configure do
    enable :logging, :dump_errors
    disable :show_exceptions
    set :raise_errors, false
    enable :protection
  end

  get '/' do
    "Hello World!"
  end
  
  # Start the server if the ruby file is executed
  run! if app_file == $0
  
end}
    name = 'app/app.rb'
    make_file(content, name)
  end
  
  def make_config_ru
    content = %q{require './app'
run MyApp}
    name = 'app/config.ru'
    make_file(content, name)
  end
  
  def make_gemfile
    content = %q{source "http://rubygems.org"
gem 'sinatra'}
    name = 'app/Gemfile'
    make_file(content, name)
  end
  
  def make_gemfile_lock
    content = %q{GEM
  remote: http://rubygems.org/
  specs:
    rack (1.5.2)
    rack-protection (1.5.3)
      rack
    sinatra (1.4.5)
      rack (~> 1.4)
      rack-protection (~> 1.4)
      tilt (~> 1.3, >= 1.3.4)
    tilt (1.4.1)
      
PLATFORMS
  ruby
  
DEPENDENCIES
  sinatra}
    name = 'app/Gemfile.lock'
    make_file(content, name)
  end
  
  def make_file(content, name)
    File.open(name, 'w') do |f|
      f.write(content)
      f.close
    end
  end
  
  def create_repository
    FileUtils::cd('app')
    `git init`
    `git add .`
    `git commit -m "first commit"`
    `git remote add origin git@github.com:jjlabrador/test_repo.git`
    `git push origin master`
  end
  
  def deploy
     #`heroku login`
    `heroku create --stack cedar`
    `git push heroku master`
    # http://infinite-retreat-9099.herokuapp.com/
  end
  
end