Gem::Specification.new do |s|
  s.name        = 'ruql'
  s.version     = '0.0.3'
  s.date        = '2013-12-16'
  s.summary     = "Ruby question language"
  s.description = "Ruby-embedded DSL for creating short-answer quiz questions"
  s.authors     = ["Armando Fox"]
  s.email       = 'fox@cs.berkeley.edu'
  s.files = []
  s.files = Dir.glob("lib/**/*.rb")
  s.files += Dir.glob("config/locales/*.yml")
  # add the templates
  s.files += Dir["templates/*.erb"]
  s.executables << 'ruql'
  # dependencies
  s.add_runtime_dependency 'builder', '~> 3.2'
  s.add_runtime_dependency 'getopt', '~> 1.4'
  s.add_runtime_dependency 'sass', '~> 3.2'
  s.add_runtime_dependency 'json', '~> 1.8'
  s.add_runtime_dependency 'htmlentities', '~> 4.3'
  s.homepage    = 'http://github.com/saasbook/ruql'
  s.license       = 'CC By-SA'
end
