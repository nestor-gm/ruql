require 'fileutils'

class Server
  attr_accessor :quizzes
  
  def initialize(quizzes)
    @quizzes = quizzes
  end
  
  def install_gem
    Gem.loaded_specs['ruql']
  end
  
  def make_server
    make_directories
    make_layout
    #$stderr.puts @quizzes[0].data
  end
  
  def make_directories
    FileUtils::mkdir_p 'app/views'
  end
  
  def make_layout
    if (install_gem == nil)
      src_path = File.expand_path(Dir.pwd, '../../..') + '/templates/htmlform.html.erb'
    else
      src_path = File.join(Gem.loaded_specs['ruql'].full_gem_path, 'templates/htmlform.html.erb')
    end
    FileUtils::cp(src_path, FileUtils::pwd + '/app/views/layout.htmlform.html.erb')
  end
end