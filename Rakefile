task :default => :ruql

desc "Run Ruql with HtmlForm renderer (with JavaScript validation)"
task :ruql do
  sh "ruby -Ilib bin/ruql examples/example.rb HtmlForm > examples/file.html"
end

desc "Run Ruql with HtmlForm renderer (with a template)"
task :template do
  sh "ruby -Ilib bin/ruql examples/example.rb HtmlForm -t templates/htmlform.html.erb > examples/output.html"
end

desc "Run Ruql with HtmlForm renderer (with a template). Another example."
task :template2 do
  sh "ruby -Ilib bin/ruql examples/example2.rb HtmlForm -t templates/htmlform.html.erb > examples/output2.html"
end

desc "Run Ruql with HtmlForm renderer (with a template). 090414 example."
task :s090414 do
  sh "ruby -Ilib bin/ruql examples/090414.rb HtmlForm -t examples/plform.html.erb > examples/090414.html"
end

desc "Run Ruql with HtmlForm renderer and HTML embed (with JavaScript validation)"
task :html do
  sh "ruby -Ilib bin/ruql examples/example.rb HtmlForm -h examples/mathjax.html > examples/file.html"
end

desc "Run Ruql with HtmlForm renderer and multiple HTML embed (with JavaScript validation)"
task :mhtml do
  sh "ruby -Ilib bin/ruql examples/example.rb HtmlForm -h examples/mathjax.html -h examples/mathjax.html > examples/file.html"
end

desc "Run Ruql with HtmlForm renderer with JavaScript"
task :js do
  sh "ruby -Ilib bin/ruql examples/example.rb HtmlForm -j examples/prueba.js > examples/file.html"
end

desc "Run Ruql with HtmlForm renderer with multiple JavaScript"
task :mjs do
  sh "ruby -Ilib bin/ruql examples/example.rb HtmlForm -j examples/prueba.js -j examples/prueba.js > examples/file.html"
end

desc "Run Ruql with HtmlForm renderer and CSS"
task :css do
  sh "ruby -Ilib bin/ruql examples/example.rb HtmlForm -c examples/estilo.css > examples/file.html"
end

desc "Run Ruql with HtmlForm renderer and multiple CSS"
task :mcss do
  sh "ruby -Ilib bin/ruql examples/example.rb HtmlForm -c examples/estilo.css -c examples/estilo.css > examples/file.html"
end

desc "Run the HtmlForm tests"
task :test do
  sh "rspec spec/html_form_renderer_spec.rb"
end

desc "Install Ruql using RVM"
task :install do
  sh "gem build ruql.gemspec"
  sh "gem install ./ruql-0.0.3.gem"
end

desc "Uninstall Ruql"
task :uninstall do
  sh "gem uninstall ruql"
end
