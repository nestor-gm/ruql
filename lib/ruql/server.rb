#encoding: utf-8
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
    make_layout
    make_login
    make_results
    write_spreadsheet if !@google_drive.empty?
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
    set :session_secret, '#{@google_drive[:spreadsheet_id].gsub('-', ('a'..'z').to_a[rand(26)])}'
    enable :protection
  end

  use Rack::Session::Pool, :expire_after => 1800
  
  students = #{@students}
  quiz_name = '#{@title}'
  completed_quiz = []
  
  get '/' do
    if (session[:current_user])
      send_file 'views/#{@title}.html'
    else
      erb :login, :locals => {:title => "Autenticación", :error => {}}
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
    <link rel="stylesheet" href="http://getbootstrap.com/examples/signin/signin.css">
    <link rel="stylesheet" href="http://getbootstrap.com/examples/sticky-footer-navbar/sticky-footer-navbar.css">
    <link rel="stylesheet" href="http://getbootstrap.com/examples/jumbotron-narrow/jumbotron-narrow.css">
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
  
end