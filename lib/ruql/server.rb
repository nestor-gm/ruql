require 'fileutils'
require 'io/console'
require 'google_drive'

class Server
  attr_accessor :quizzes
  attr_reader :title, :students, :teachers, :schedule, :heroku, :google_drive
  
  def initialize(quizzes)
    @quiz = quizzes[0]
    @html = @quiz.output
    @students = @quiz.users
    @teachers = @quiz.admins
    @schedule = @quiz.time
    @heroku = @quiz.heroku_config || {}
    @title = @heroku[:domain] || @quiz.title
    @google_drive = @quiz.drive || {}
  end
  
  def make_server
    make_directories
    make_html
    make_gemfile
    make_rakefile
    make_app_rb
    make_config_ru
    write_spreadsheet
  end
  
  def make_directories
    #FileUtils::cd('../')              # Arreglar path para ejecutar desde la gema
    FileUtils::mkdir_p 'app/views'
  end
  
  def make_html
    make_file(@html, "app/views/#{@title}.html")
  end
  
  def make_app_rb
    content = %Q{require 'sinatra/base'

class MyApp < Sinatra::Base
  
  configure do
    enable :logging, :dump_errors
    disable :show_exceptions
    set :raise_errors, false
    enable :protection
  end

  get '/' do
    send_file 'views/#{@title}.html'
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
  sh "heroku create --stack cedar #{@title.downcase.gsub(/\W/, '-')}"
  sh "git push heroku master"
end

desc "Build all"
task :build do
  [:bundle, :git, :heroku].each { |task| Rake::Task[task].execute }
end

desc "Run local server"
task :run do
  sh "ruby app.rb"
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
  
  def google_login
    puts "Enter your Google credentials."
    print "Email: "
    email = STDIN.gets.chomp!
    print "Password (typing will be hidden): "
    password = STDIN.noecho(&:gets)
    puts
    GoogleDrive.login(email, password)
  end
  
  def get_spreadsheet
    session = google_login
    session.spreadsheet_by_key(@google_drive[:spreadsheet_id]).worksheets[0]
  end
  
  def write_spreadsheet
    spreadsheet = get_spreadsheet
    spreadsheet[1, 1] ="Email"
    @students.each_with_index { |student, index| spreadsheet[index + 2, 1] = student }
    spreadsheet.save()
    spreadsheet.reload()
  end
  
end