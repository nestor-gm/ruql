#encoding: utf-8
require 'fileutils'
require 'io/console'
require 'google_drive'
require 'yaml'

class Server
  attr_accessor :quizzes
  attr_reader :title, :students, :teachers, :schedule, :heroku, :google_drive, :credentials
  
  def initialize(quizzes)
    @quiz = quizzes[0]
    @html = @quiz.output
    @students = @quiz.users
    @teachers = @quiz.admins
    @schedule = @quiz.time
    @heroku = @quiz.heroku_config || {}
    @title = @heroku[:domain] || @quiz.title
    @google_drive = @quiz.drive || {}
    begin
      @credentials = YAML.load_file(File.expand_path(@google_drive[:login]))
    rescue Exception => e
      $stderr.puts "#{e.message}"
    end
  end
  
  def make_server
    make_directories
    make_html
    make_gemfile
    make_rakefile
    make_app_rb
    make_config_ru
    make_layout
    make_login
    make_results
    make_available
    drive if !@google_drive.empty?
  end
  
  def make_directories
    #FileUtils::cd('../')              # Arreglar path para ejecutar desde la gema
    FileUtils::mkdir_p 'app/views'
  end
  
  def make_html
    make_file(@html, "app/views/#{@title}.html")
  end
  
  def make_app_rb
    content = %Q{#encoding: utf-8
require 'sinatra/base'

class MyApp < Sinatra::Base
  
  configure do
    enable :logging, :dump_errors
    disable :show_exceptions
    set :raise_errors, false
    set :session_secret, '#{@title.crypt(@title)}'
    enable :protection
  end

  use Rack::Session::Pool, :expire_after => 1800
  
  helpers do
    def calculate_time(type, schedule)
      date = schedule[("date_" + type).to_sym].split('-')
      time = schedule[("time_" + type).to_sym].split(':')
      Time.new(date[0], date[1], date[2], time[0], time[1]).getutc.to_i
    end
    
    def before_available(schedule)
      start_utc_seconds = calculate_time('start', schedule)
      
      if (Time.now.getutc.to_i < start_utc_seconds)
        return true
      else
        return false
      end
    end
    
    def after_available(schedule)
      finish_utc_seconds = calculate_time('finish', schedule)
      
      if (Time.now.getutc.to_i > finish_utc_seconds)
        return true
      else
        return false
      end
    end
  end
  
  students = #{@students}
  quiz_name = '#{@title}'
  completed_quiz = []
  schedule = #{@schedule}
  
  get '/' do
    if (before_available(schedule))
      date = schedule[:date_start].split('-')
      time = schedule[:time_start]
      erb :available, :locals => {:state => 'not started', :title => quiz_name, :date => [date[2], date[1], date[0]].join('/'), :time => time}
    elsif (after_available(schedule))
      date = schedule[:date_finish].split('-')
      time = schedule[:time_finish]
      erb :available, :locals => {:state => 'finished', :title => quiz_name, :date => [date[2], date[1], date[0]].join('/'), :time => time}
    else
      if (session[:current_user])
        send_file 'views/My Quiz.html'
      else
        erb :login, :locals => {:title => "Autenticación", :error => {}}
      end
    end
  end
  
  post '/' do
    user_email = params[:email]
    if ((students.key?(user_email.to_sym)) && (!completed_quiz.include?(user_email.to_s)))
      session[:current_user] = user_email.to_s
      redirect '/quiz'
    else
      if (!students.key?(user_email.to_sym))
        erb :login, :locals => {:title => "Autenticación", :error => {:code => 'not exists', :msg => 'no dispone de permisos para realizar este cuestionario.', :type => 'danger'}}
      elsif (completed_quiz.include?(user_email.to_s))
        erb :login, :locals => {:title => "Autenticación", :error => {:code => 'completed', :msg => 'usted ya ha realizado el cuestionario.', :type => 'warning'}}
      end
    end
  end

  get '/quiz' do
    if (session[:current_user])
      send_file 'views/My Quiz.html'
    else
      redirect '/'
    end
  end
  
  post '/quiz' do
    if (session[:completed] == nil)
      session[:completed] = true
      erb :results, :locals => {:title => "Resultado", :quiz_name => quiz_name, :email => session[:current_user], :full_name => students[session[:current_user].to_sym]}
    else
      redirect '/logout'
    end
  end
  
  get '/logout' do
    completed_quiz << session[:current_user]
    session.clear
    redirect '/'
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
  
  def make_layout
    content = %q{<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <!-- Latest compiled and minified CSS -->
    <link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css">
    <style type="text/css">
      /* Signin */
      body{padding-top:40px;padding-bottom:40px;background-color:#eee}.form-signin{max-width:330px;padding:15px;margin:0 auto}.form-signin .checkbox,.form-signin .form-signin-heading{margin-bottom:10px}.form-signin .checkbox{font-weight:400}.form-signin .form-control{position:relative;height:auto;-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box;padding:10px;font-size:16px}.form-signin .form-control:focus{z-index:2}.form-signin input[type=email]{margin-bottom:-1px;border-bottom-right-radius:0;border-bottom-left-radius:0}.form-signin input[type=password]{margin-bottom:10px;border-top-left-radius:0;border-top-right-radius:0}
      /* Sticky footer navbar */
      html{position:relative;min-height:100%}body{margin-bottom:60px}#footer{position:absolute;bottom:0;width:100%;height:60px;background-color:#f5f5f5}body>.container{padding:60px 15px 0}.container .text-muted{margin:20px 0}#footer>.container{padding-right:15px;padding-left:15px}code{font-size:80%}
      /* Jumbotron narrow */
      body{padding-top:20px;padding-bottom:20px}.footer,.header,.marketing{padding-right:15px;padding-left:15px}.header{border-bottom:1px solid #e5e5e5}.header h3{padding-bottom:19px;margin-top:0;margin-bottom:0;line-height:40px}.footer{padding-top:19px;color:#777;border-top:1px solid #e5e5e5}@media (min-width:768px){.container{max-width:730px}}.container-narrow>hr{margin:30px 0}.jumbotron{text-align:center;border-bottom:1px solid #e5e5e5}.jumbotron .btn{padding:14px 24px;font-size:21px}.marketing{margin:40px 0}.marketing p+h4{margin-top:28px}@media screen and (min-width:768px){.footer,.header,.marketing{padding-right:0;padding-left:0}.header{margin-bottom:30px}.jumbotron{border-bottom:0}}
    </style>
    <title><%= title %></title>
    <!-- HTML5 shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"></script>
      <script src="https://oss.maxcdn.com/libs/respond.js/1.4.2/respond.min.js"></script>
    <![endif]-->
  </head>
  <body>
    <div class="container">
      <%= yield %>
    </div>
    <!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
    <script src="https://code.jquery.com/jquery-1.11.1.min.js"></script>
    <!-- Latest compiled and minified JavaScript -->
    <script src="//netdna.bootstrapcdn.com/bootstrap/3.1.1/js/bootstrap.min.js"></script>
  </body>
</html>}
    name = 'app/views/layout.erb'
    make_file(content, name)
  end
  
  def make_login
    content = %q{<div class="jumbotron">
  <% if (!error.empty?) %>
    <div class="alert alert-<%= error[:type] %> alert-dismissable">
      <button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>
      <strong>Error</strong>: <%= error[:msg] %>
    </div>
  <% end %>
   
  <h1>Autenticaci&oacute;n</h1>
  <div class="alert alert-info">
    Para poder realizar el cuestionario, por favor, introduzca el email de su cuenta de <strong>Google</strong>. 
    Si no dispone de uno, haga click <strong><a href="http://accounts.google.com/SignUp?service=mail" target="_blank">aqu&iacute;</a></strong> para crearlo.
  </div>
  <form class="form-signin" role="form" method="post" action="/">
    <input type="email" class="form-control" placeholder="Email" name="email" required autofocus>
    <br>
    <button class="btn btn-lg btn-primary btn-block" type="submit">Continuar</button>
  </form>
  <br>
</div>}
    name = 'app/views/login.erb'
    make_file(content, name)
  end
  
  def make_results
    content = %q{<h1>Resultados</h1>

<h3>Cuestionario</h3>
<%= quiz_name %>

<h3>Alumno</h3>
<ul>
<li>Nombre: <%= full_name[:name] %></li>
<li>Apellidos: <%= full_name[:surname] %></li>
<li>Email: <%= email %></li>
</ul>

<h3>Informaci&oacute;n del ex&aacute;men</h3>
.
.
.
.
<br><br><br>
<a href="/logout" class="btn btn-primary">Finalizar revisi&oacute;n</a>}
    name = 'app/views/results.erb'
    make_file(content, name)
  end
  
  def make_available
    content = %q{<div class="jumbotron">
  <h1><%= title %></h1>
  <br />
  <% if (state == 'not started') %>
    <div class="alert alert-warning">
      El cuestionario se abrir&aacute; el <%= date %> a las <%= time %> horas.
      Vuelva en ese momento para poder realizarlo.
    </div>
  <% else %>
    <div class="alert alert-danger">
      El cuestionario se cerr&oacute; el <%= date %> a las <%= time %> horas.
      Ya no es posible realizar ning&uacute;n env&iacute;o.
    </div>
  <% end %>
</div>}
    name = 'app/views/available.erb'
    make_file(content, name)
  end
  
  def make_file(content, name)
    File.open(name, 'w') do |f|
      f.write(content)
      f.close
    end
  end
  
  def google_login
    email = @credentials['email']
    password = @credentials['password']
    begin
      GoogleDrive.login(email, password)
    rescue Exception => e
      $stderr.puts e.message
      exit
    end
  end
  
  def get_spreadsheet(session, file)
    session.spreadsheet_by_url(file.worksheets_feed_url).worksheets[0]
  end
  
  def write_spreadsheet(session, file)
    spreadsheet = get_spreadsheet(session, file)
    %w{Email Surname Name Mark}.each_with_index { |value, index| spreadsheet[1, index + 1] = value }
    @students.each_with_index do |k, i|
      key = k[0]
      value = k[1]
      spreadsheet[i + 2, 1] = key.to_s
      spreadsheet[i + 2, 2] = value[:surname]
      spreadsheet[i + 2, 3] = value[:name]
    end
    spreadsheet.save()
    spreadsheet.reload()
  end
  
  def create_folder(session)
    root_folder = session.root_collection
    if (@google_drive.key?(:path))
      local_root = root_folder
      folders = @google_drive[:path].split('/')
      folders.each do |folder|
        if (local_root.subcollection_by_title(folder) == nil)
          local_root.create_subcollection(folder)
          local_root = local_root.subcollection_by_title(folder)
        else
          local_root = local_root.subcollection_by_title(folder)
        end
      end
      local_root.create_subcollection(@google_drive[:folder])
    else
      root_folder.create_subcollection(@google_drive[:folder])
    end
  end
  
  def drive
    session = google_login
    dest = create_folder(session)
    file = session.create_spreadsheet(@google_drive[:spreadsheet_name])
    dest.add(file)
    session.root_collection.remove(file)
    write_spreadsheet(session, file)
  end
  
end