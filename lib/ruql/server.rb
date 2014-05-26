require 'fileutils'

class Server
  attr_accessor :quizzes
  attr_reader :title
  
  def initialize(quizzes)
    @quizzes = quizzes[0]
    @title = @quizzes.title
  end
  
  def make_server
    make_directories
    make_gemfile
    make_rakefile
    make_app_rb
    make_config_ru
    #$stderr.puts @quizzes[0]
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
  
  def make_rakefile
    content = %Q{task :default => :build
    
desc "Generate Gemfile.lock"
task :bundle do
  sh "bundle install"
end

desc "Create local git repository"
task :git do
  sh "git init"
  sh "git add ."
  sh %q{git commit -m "Creating quiz"}
end

desc "Deploy to Heroku"
task :heroku do
  sh "heroku create --stack cedar #{@title.downcase.gsub(' ', '-')}"
  sh "git push heroku master"
end

desc "Build all"
task :build do
  [:bundle, :git, :heroku].each { |task| Rake::Task[task].execute }
end}
    name = 'app/Rakefile'
    make_file(content, name)
  end
  
  def make_file(content, name)
    File.open(name, 'w') do |f|
      f.write(content)
      f.close
    end
  end
  
end