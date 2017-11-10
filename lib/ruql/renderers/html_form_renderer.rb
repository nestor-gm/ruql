class HtmlFormRenderer
  require 'builder'
  require 'erb'
  require 'json'
  require 'sass'
  require 'yaml'
  require 'i18n'
  require 'locale'
  
  attr_reader :output

  def initialize(quiz,options={})
    @css = options.delete('c') || options.delete('css')
    @js = options.delete('j') || options.delete('js')
    @html = options.delete('h') || options.delete('html')
    @show_solutions = options.delete('s') || options.delete('solutions')
    @template = options.delete('t') || options.delete('template')
    @output = ''
    @quiz = quiz
    @h = Builder::XmlMarkup.new(:target => @output, :indent => 2)
    @data = {}
    @size_inputs = []
    @size_divs = []
    @size_dd_divs = []
    @language = (Locale.current[0].language || 'en').to_sym
  end

  def render_quiz
    load_yml
    if @template
      render_with_template do
        @output
      end
    else
      @h.html do
        @h.head do |h|
          @h.title @quiz.title
          insert_resources_head(h)
        end
        @h.body do |b|
          render_questions
          insert_resources_body(b)
        end
      end
    end
    self
  end

  def render_with_template
    # local variables that should be in scope in the template 
    quiz = @quiz
    title = translate(:title, 'quiz') unless @title
    @css_custom = insert_css_js(true, @css, 'css') if @css
    @bootstrap_css = insert_bootstrap_css
    @bootstrap_js = insert_bootstrap_js
    @js_custom = insert_css_js(true, @js, 'js') if @js
    @jQuery = insert_jQuery('', true)
    @mathjax = insert_mathjax(true)
    @codemirror = insert_codemirror(true)
    @codemirror_object = insert_codemirror_object(true)
    @xregexp = insert_xregexp(true)
    @i18n = yml_to_json(true)
    @dragdrop = insert_drag_drop(true)
    @context_menu = insert_contextMenu(true)
    @context_menu_css = insert_contextMenu_css(true)
   
    render_questions
    
    @validation_js = insert_defaultJS(@quiz.points, true)
    @sass = ''
    @sass = insert_sass('input') if !@size_inputs.empty?
    @sass << insert_sass('div') if !@size_divs.empty?
    @sass << insert_sass('dd_div') if !@size_dd_divs.empty?
    
    # the ERB template includes 'yield' where questions should go:
    output = ERB.new(IO.read(File.expand_path @template)).result(binding)
    @output = output
  end
  
  def content_form
    @h.ol :class => 'questions' do
      @quiz.questions.each_with_index do |q,i|
        raise "#{translate(:question, 'exceptions')}-#{i+1}: #{translate(:text, 'exceptions')}" if q.question_text == nil
        raise "#{translate(:question, 'exceptions')}-#{i+1}: #{translate(:answer, 'exceptions')}" if q.answers.length == 0
        case q
        when SelectMultiple then render_select_multiple(q,i)
        when MultipleChoice, TrueFalse then render_multiple_choice(q,i)
        when FillIn then render_fill_in(q, i)
        when Programming then render_programming(q, i)
        else
          raise "Unknown question type: #{q}"
        end
      end
    end
    @h.div :id => 'score', :class => 'score' do
    end
    @h.div :class => 'btn-footer' do
      insert_button('submit', translate(:submit, 'buttons'), 'btn btn-primary')
      insert_button('reset', translate(:reset, 'buttons'), 'btn btn-info')
      insert_button('deleteAnswers', translate(:delete, 'buttons'), 'btn btn-warning')
      insert_button('deleteStorage', translate(:deleteAll, 'buttons'), 'btn btn-danger')
    end
  end
  
  def render_questions
    render_random_seed
    @h.form(:id => 'form') do
      content_form
    end
  end

  def insert_input(type, id, name, klass, answer)
    @h.input(:type => type, :id => id, :name => name, :class => klass) { |p| 
      p << answer.answer_text
      p << %Q{<br class="#{id}br">}
    }
    @h.div(:id => "#{id}r", :class => 'quiz') do
    end
  end
  
  def get_drag_drop_answers(answers, keys, values)
    answers.each do |a|
      keys << a.answer_text.keys[0].to_s
      a.answer_text.each_value do |v|
        values << v
      end
    end
  end
  
  def store_answers(answers, index, klass, id_klass, type_input, klass_input)
    id_answer = 1
    
    answers.each do |answer|
      @data[:"question-#{index}"][:answers]["#{id_klass}#{index + 1}-#{id_answer}".to_sym] = {:answer_text => answer.answer_text, :correct => answer.correct, 
                                                                                              :explanation => answer.explanation}
      if ((klass == DragDrop_MC) || (klass == DragDrop_SM))
        @data[:"question-#{index}"][:answers]["#{id_klass}#{index + 1}-#{id_answer}".to_sym][:type] = "Hash"
      else
        insert_input(type_input, "#{id_klass}#{index + 1}-#{id_answer}", "#{id_klass}#{index + 1}", klass_input, answer)
      end
      id_answer += 1
    end
  end
  
  def insert_drag_drop_keys(keys, id, q, index, klass, clone)
    @h.div(:id => "col1-q#{q}-#{id}", :class => 'col1') do |d|
      keys.each do |k|
        @h.a(:class => "btn btn-default btn-sm disabled button-q#{q}-#{id}", :draggable => 'false') do |b|
          b << k
        end
        @h.br
      end
    end
    @h.div(:id => "col2-q#{q}-#{id}", :class => 'col2') do 
      keys.length.times do |i|
        if (id =~ /qddmc/)
          @h.input(:id => "#{id}#{index + 1}-#{i + 1}", :name => "#{id}#{index + 1}-#{i + 1}", :type => 'text', :class => klass, :ondrop => "drop(event, '#{id}#{index + 1}-#{i + 1}', #{clone})", 
:ondragover => "allowDrop(event)")
          @h.br
        elsif (id =~ /qddsm/)
          @h.div(:id => "#{id}#{index + 1}-#{i + 1}", :type => 'text', :class => klass, :ondrop => "drop(event, '#{id}#{index + 1}-#{i + 1}', #{clone})", :ondragover => "allowDrop(event)") do end
          @h.input(:type => 'hidden', :name => "#{id}#{index + 1}-#{i + 1}")
        end
      end
    end
  end
  
  def insert_drag_drop_values(d, values, id, index)
    counter = 1
    d << translate(:answers, '') + ": " if id =~ /qddsm/
    values.each do |v|
      @h.a(:id => "#{id}a#{index + 1}-#{counter}", :name => "#{id}a#{index + 1}-#{counter}", :class => "btn btn-default btn-sm button-#{id}", :draggable => 'true', :ondragstart => 'drag(event)') do 
|b|
        b << v           
      end
      counter += 1
      @h.br if id =~ /qddmc/
    end
  end
  
  def get_max_length_select_multiple_div(answers)
    max = []
    answers.each do |item| 
      item.answer_text.each_value do |a|
        local_max = 0
        if (a.class == Array)
          a.each do |value|
            local_max += value.length
          end
        else
          local_max += a.length
        end
        max << local_max
      end
    end
    max.max
  end
  
  def render_multiple_choice(q,index)
    render_question_text(q, index) do
      answers =
        if q.class == TrueFalse then q.answers.sort.reverse # True always first
        elsif q.randomize then q.answers.sort_by { rand }
        else q.answers
        end
      @h.ol :class => 'answers' do
        
        if (q.class == DragDrop_MC)
          keys, values = [], []
          get_drag_drop_answers(answers, keys, values)
          values.sort_by! { rand }
        end
        
        # Store answers for question-index
        ((q.class == MultipleChoice) || (q.class == TrueFalse)) ? id_klass = "qmc" : id_klass = "qddmc"
        store_answers(answers, index, q.class, id_klass, 'radio', 'select')
        
        if (q.class == DragDrop_MC)
          @h.div do
            insert_drag_drop_keys(keys, 'qddmc', index + 1, index, "dragdropmc input-qddmc", true)
            @h.div(:id => "col3-q#{index}-qddmc", :class => 'col3') do |d|
              insert_drag_drop_values(d, values, 'qddmc', index)
            end
          end
          @h.div(:class => 'clear-qdd')
        end
        @h.br
      end
    end
    question_comment(q)
    q.class == MultipleChoice ? flag = true : flag = false
    insert_buttons_each_question(index, flag)
    self
  end

  def render_select_multiple(q,index)
    render_question_text(q, index) do
      answers =
      if q.randomize then q.answers.sort_by { rand }
      else q.answers
      end
      @h.ol :class => 'answers' do
        
        if (q.class == DragDrop_SM)
          keys, values = [], []
          get_drag_drop_answers(answers, keys, values)
          values.flatten!.sort_by! { rand }
        end
        
        # Store answers for question-index
        q.class == SelectMultiple ? id_klass = "qsm" : id_klass = "qddsm"
        store_answers(answers, index, q.class, id_klass, 'checkbox', 'check')
        
        if (q.class == DragDrop_SM)
          max = get_max_length_select_multiple_div(answers)
          @size_dd_divs << max
          
          @h.div do
            insert_drag_drop_keys(keys, 'qddsm', index + 1, index, "dragdropsm size-#{max}", false)
            @h.div(:class => 'clear-qdd')
            @h.br
            @h.div(:id => "answers-q#{index + 1}-qddsm", :ondrop => "drop(event, 'answers-q#{index + 1}-qddsm', false)", :ondragover => "allowDrop(event)") do |d|
              insert_drag_drop_values(d, values, 'qddsm', index)
            end
          end
          
        end
        @h.br
      end
    end
    question_comment(q)
    q.class == SelectMultiple ? flag = true : flag = false
    insert_buttons_each_question(index, flag)
    self
  end
  
  def type_answer_fill_in(answer, item, idx, id_answer, class_question) 
    if (item.class == Regexp)
      ans = item.source
      type = 'Regexp'
      [0, -1].each {|index| ans.insert(index, '/')}
      opts = item.options
      ans << 'i' if (opts & 1 == 1)
      ans << 'x' if (opts & 2 == 2)
      ans << 'm' if (opts & 4 == 4)
    elsif (item.class == String)
      ans = item.downcase
      type = 'String'
    elsif (item.class == Fixnum)
      ans = item
      type = 'Fixnum'
    elsif (item.class == JavaScript)
      ans = item.to_javascript
      type = 'JavaScript'
    else
      $stderr.puts "Answer type #{item.class} not supported in this renderer!"
      exit
    end
    @data[:"question-#{idx}"][:answers]["#{class_question}#{idx + 1}-#{id_answer}".to_sym] = {:answer_text => ans, :correct => answer.correct, 
                                                                                              :explanation => answer.explanation, :type => type}
  end
  
  def render_fill_in(q, idx)
    render_question_text(q, idx) do
      
      question_comment(q)
      q.class == FillIn ? class_question = "qfi" : class_question = "qddfi"
      
      # Store answers for question-idx
      answer = q.answers[0]
      distractor = q.answers[1..-1]
      distractors = []
      
      answers = (answer.answer_text.kind_of?(Array) ? answer.answer_text : [answer.answer_text])
      
      if (!distractor.empty?)
        distractor.each do |d|
          distractors << d
        end
      end
      
      id_answer = 1
      answers.each do |a|
        type_answer_fill_in(answer, a, idx, id_answer, class_question)
        id_answer += 1
      end
      
      id_distractor = 2
      if (!distractor.empty?)
        distractors.each_index do |i|
          type_answer_fill_in(distractors[i], distractors[i].answer_text, idx, id_distractor, class_question)
          id_distractor += 1
        end
      end
      insert_buttons_each_question(idx)
    end
  end
  
  def render_programming(q, index)
    render_question_text(q, index) do
      answer = q.answers[0]
      @h.ol :class => 'answers' do
        # Store answers for question-index
        @data[:"question-#{index}"][:answers]["qp#{index + 1}-1".to_sym] = {:answer_text => answer.answer_text.to_javascript, :correct => answer.correct, 
                                                                            :explanation => answer.explanation}
        @h.textarea(:id => "qp#{index + 1}-1", :name => "qp#{index + 1}-1", :class =>'programming', :rows => 5, :cols => 80, :height => q.height, :width => q.width, :placeholder => 
"#{translate(:placeholder, 'questions')}...") do
        end
        @h.br
        @h.br
      end
    end
    question_comment(q)
    insert_buttons_each_question(index)
    self
  end
  
  def hyphens_to_inputs(question, index)
    hyphen = question.question_text.scan(/(?<!\\)---+/)
    hyphen.length.times { |i|
                          nHyphen = hyphen[i].count('-')
                          @size_inputs << nHyphen
                          input = %Q{<input type="text" id="qfi#{index + 1}-#{i + 1}" name="qfi#{index + 1}-#{i + 1}" class="fillin size-#{nHyphen}"></input>} if question.class == FillIn
                          input = %Q{<input id="qddfi#{index + 1}-#{i + 1}" name="qddfi#{index + 1}-#{i + 1}" class="dragdropfi size-#{nHyphen}" ondrop="drop(event,'qddfi#{index + 1}-#{i + 1}', 
true)" 
                          ondragover="allowDrop(event)"></input>} if question.class == DragDrop_FI
                          question.question_text.sub!(/(?<!\\)---+/, input)
                        }
    question.question_text.gsub!(/\\-/, '-')
    
    if (question.class == FillIn)
      question.question_text << %Q{<div id="qfi#{index + 1}-#{hyphen.length}r" class="quiz"></div></br></br>} 
    
    elsif (question.class == DragDrop_FI)
      question.question_text << "<br/><br/>"
      question.question_text << "<div> #{translate(:answers, '')}: "
      question.answers[0].answer_text.each_with_index do |a, i|
        @size_divs << a.to_s.length
        question.question_text << %Q{<a class="dragdropfi size-#{a.to_s.length} btn btn-default btn-sm" id="qddfia#{i + 1}-#{i + 1}" draggable="true" 
        ondragstart="drag(event)">#{a}</a>&nbsp&nbsp}
      end
      question.question_text << "<div/>"
      question.question_text << "</br></br>"
      
    else 
      question.raw? ? question.question_text : question.question_text << "<br></br>"
    end
  end
  
  def render_question_text(question,index)
    html_args = {
      :id => "question-#{index}",
      :class => ['question', question.class.to_s.downcase, (question.multiple ? 'multiple' : '')]
        .join(' ')
    }
    @h.li html_args  do
      @h.div :class => 'quiz text' do |d|
        questionText = question.question_text.clone
        qtext = "[#{question.points} point#{'s' if question.points>1}] " <<
          ('Select ALL that apply: ' if question.multiple).to_s <<
          hyphens_to_inputs(question, index)
          
          # Hash with questions and all posibles answers
          if ((question.class == FillIn) || (question.class == DragDrop_FI))
            @data[html_args[:id].to_sym] = {:question_text => questionText, :answers => {}, :points => question.points, 
                                            :order => question.order, :question_comment => question.question_comment}
          elsif (question.class == Programming)
            if (question.language == 'JavaScript')
              @data[html_args[:id].to_sym] = {:question_text => questionText, :answers => {}, :points => question.points, 
                                              :question_comment => question.question_comment, :language => question.language,
                                              :height => question.height, :width => question.width}
            elsif (question.language == nil)
              $stderr.puts "You must specify a programming language for Programming Questions"
              exit
            else
              $stderr.puts "Programming language #{question.language} not supported in this renderer!"
              exit
            end
          else
            @data[html_args[:id].to_sym] = {:question_text => questionText, :answers => {}, :points => question.points,
                                            :question_comment => question.question_comment}
          end
          
          if (question.raw?)
              d << qtext
          else
            qtext.each_line do |p|
              d << p # preserves HTML markup
            end
          end
      end
      yield # render answers
    end
    self
  end

  def render_random_seed
    @h.comment! "Seed: #{@quiz.seed}"
  end
  
  def question_comment(q)
    @h.p :class => 'comment' do |p|
      p << q.question_comment + "<br></br>"
    end if (q.question_comment != "")
  end
  
  def insert_button(id, name, type)
    @h.a(:id => id, :class => type) do |b|
      b << name
    end
  end
  
  def insert_buttons_each_question(index, flag=false)
    insert_button("show-answer-q-#{index}", translate(:show, 'buttons'), 'btn btn-success btn-sm') if flag
    #insert_button("q-#{index}", translate(:submit, 'buttons'), 'btn btn-primary btn-sm')
    @h.br do
    end
  end
  
  def insert_resources_head(h)
    insert_defaultCSS
    insert_html(h) if @html
    insert_contextMenu_css(false)
    insert_css_js(false, @css, 'css') if @css
    insert_mathjax(false)
    insert_codemirror(false)
  end
  
  def insert_resources_body(b)
    insert_jQuery(b, false)
    insert_defaultJS(@quiz.points, false)
    insert_contextMenu(false)
    insert_xregexp(false)
    insert_css_js(false, @js, 'js') if @js
    insert_codemirror_object(false)
    insert_drag_drop(false)
    yml_to_json(false)
  end
  
  def insert_html(h)
    if (@html.class == Array)
      @html.each do |file|
        h << File.read(File.expand_path(file))
      end
    else
      h << File.read(File.expand_path(@html))
    end
  end
  
  def insert_css_js(template, attr, type)
    code = ""
    if (attr.class == Array)
      if (template)
        attr.each do |file|
          code << %Q{<link rel="stylesheet" type="text/css" href="#{File.expand_path(file)}" />\n} if type == 'css'
          code << %Q{<script type="text/javascript" src="#{File.expand_path(file)}"></script>\n} if type == 'js'
        end
      else
        attr.each do |file|
          @h.link(:rel => 'stylesheet', :type =>'text/css', :href => File.expand_path(file)) if type == 'css'
          @h.script(:type => 'text/javascript', :src => "#{File.expand_path(file)}") do
          end if type == 'js'
        end
      end
    else
      if (template)
        code << %Q{<link rel="stylesheet" type="text/css" href="#{File.expand_path(attr)}" />} if type == 'css'
        code << %Q{<script type="text/javascript" src="#{File.expand_path(@js)}"></script>\n} if type == 'js'
      else
        @h.link(:rel => 'stylesheet', :type =>'text/css', :href => File.expand_path(attr)) if type == 'css'
        @h.script(:type => 'text/javascript', :src => "#{File.expand_path(@js)}") do
        end if type == 'js'
      end
    end
    code if template
  end
  
  def insert_sass(tag)
    sass = ""
    if (tag == 'input')
      @size_inputs.uniq.sort.each { |sz| sass << "input.size-#{sz.to_s} { width: #{sz-(sz*0.3)}em}"}
    else
      @size_divs.uniq.sort.each { |sz| sass << "div.size-#{sz.to_s} { width: #{sz-(sz*0.3)}em; display: inline;}"} if tag == 'div'
      @size_dd_divs.uniq.sort.each { |sz| sass << "div.size-#{sz.to_s} { width: #{sz-(sz*0.25)}em;}"} if tag == 'dd_div'
    end
    engine = Sass::Engine.new(sass, :syntax => :scss)
    engine.options[:style] = :compact
    engine.render
  end
  
  def install_gem
    Gem.loaded_specs['ruql']
  end
  
  def insert_jQuery(h, template)
    if (install_gem == nil)
      jQuery2 = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/jQuery/jquery-2.1.0.min.js')
      jQuery1 = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/jQuery/jquery-1.11.0.min.js')
    else
      jQuery2 = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/jQuery/jquery-2.1.0.min.js'))
      jQuery1 = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/jQuery/jquery-1.11.0.min.js'))
    end
    
    if (template)
      code = %Q{
        <script type="text/javascript">
          #{jQuery2}
        </script>
        <!--[if lt IE 8]>
          <script type="text/javascript">
            #{jQuery1}
          </script>
        <![endif]-->
      }
      code
    else
      @h.script(:type => 'text/javascript') do |j|
        j << jQuery2
      end
      h << "<!--[if lt IE 8]>"
      @h.script(:type => 'text/javascript') do |j|
        j << jQuery1
      end
      h << "<![endif]-->"
    end
  end
  
  def insert_bootstrap_css
    if (install_gem == nil)
      css = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/Bootstrap-3.1.1/css/bootstrap.min.css')
    else
      css = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/Bootstrap-3.1.1/css/bootstrap.min.css'))
    end
    %Q{
      <style type="text/css">
        #{css}
      </style>
    }
  end
  
  def insert_bootstrap_js
    if (install_gem == nil)
      js = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/Bootstrap-3.1.1/js/bootstrap.min.js')
    else
      js = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/Bootstrap-3.1.1/js/bootstrap.min.js'))
    end
    %Q{
      <script type="text/javascript">
        #{js}
      </script>
    }
  end
  
  def insert_in_template(code, tags, tag, template)
    if (template)
      tags
    else
      if (tag == 'style')
        @h.style(:type =>'text/css') do |c|
          c << code
        end
      elsif (tag == 'script')
        @h.script(:type =>'text/javascript') do |j|
          j << code
        end
      end
    end
  end
  
  def insert_xregexp(template)
    if (install_gem == nil)
      code = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/XRegexp-2.0.0/xregexp-min.js')
    else
      code = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/XRegexp-2.0.0/xregexp-min.js'))
    end
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    insert_in_template(code, tags, 'script', template)
  end
  
  def insert_mathjax(template)
    if (install_gem == nil)
      config = File.read(File.expand_path(Dir.pwd, '../../..') + '/public/js/MathJax_config.js')
    else
      config = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'public/js/MathJax_config.js'))
    end
    if (template)
      code = %Q{
        <script type="text/javascript" src="https://c328740.ssl.cf1.rackcdn.com/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
        </script>
        <script type="text/javascript">
         #{config}
        </script>
      }
    else
      @h.script(:type => 'text/javascript', :src => "https://c328740.ssl.cf1.rackcdn.com/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML") do
      end
      @h.script(:type => 'text/javascript') do |j|
        j << config
      end
    end
  end
  
  def insert_codemirror(template)
    if (install_gem == nil)
      css = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/CodeMirror-4.3.0/css/codemirror.css')
      js = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/CodeMirror-4.3.0/js/codemirror.min.js')
      mode_js = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/CodeMirror-4.3.0/mode/javascript/javascript.js')
    else
      css = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/CodeMirror-4.3.0/css/codemirror.css'))
      js = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/CodeMirror-4.3.0/js/codemirror.min.js'))
      mode_js = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/CodeMirror-4.3.0/mode/javascript/javascript.js'))
    end
    if (template)
      tags = %Q{
        <style type="text/css">
          #{css}
        </style>
        <script type="text/javascript">
          #{js}
        </script>
        <script type="text/javascript">
          #{mode_js}
        </script>
      }
    else
      @h.style(:type =>'text/css') do |s|
        s << css
      end
      @h.script(:type => 'text/javascript') do |j|
        j << js
      end
      @h.script(:type => 'text/javascript') do |j|
        j << mode_js
      end
    end
  end
  
  def insert_codemirror_object(template)
    if (install_gem == nil)
      code = File.read(File.expand_path(Dir.pwd, '../../..') + '/public/js/CodeMirror_Object.js')
    else
      code = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'public/js/CodeMirror_Object.js'))
    end
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    insert_in_template(code, tags, 'script', template)
  end
  
  def insert_contextMenu(template)
    if (install_gem == nil)
      js1 = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/ContextJS/js/context.js')
      js2 = File.read(File.expand_path(Dir.pwd, '../../..') + '/public/js/ContextJS_init.js')
    else
      js1 = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/ContextJS/js/context.js'))
      js2 = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'public/js/ContextJS_init.js'))
    end
    code = %Q{
      #{js1}
      #{js2}
      
      $(document).mousedown(function(e){ 
        if( e.button == 2 ) {
          id_answer = e.target.id;
          if (id_answer.match(/^qfi/)) {
            numQuestion = parseInt(id_answer.split('-')[0].slice(3)) - 1;
            try {
              if (data["question-" + numQuestion.toString()]['answers'][id_answer]['type'] != "JavaScript") {
                answer = data["question-" + numQuestion.toString()]['answers'][id_answer]['answer_text'];
                type = data["question-" + numQuestion.toString()]['answers'][id_answer]['type'];
                context.attach('#' + id_answer, [
                  
                  {header: '#{translate(:show, 'buttons')}'},
                  {text: 'Ver respuesta', subMenu: [
                    {header: type},
                    {text: answer}
                  ]}
                ]);
              }
            }
            catch(err) {}
          }
        };
      });
    }
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    insert_in_template(code, tags, 'script', template)
  end
  
  def insert_contextMenu_css(template)
    if (install_gem == nil)
      code = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/ContextJS/css/context.standalone.css')
    else
      code = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/ContextJS/css/context.standalone.css'))
    end
    tags = %Q{
      <style type="text/css">
        #{code}
      </style>
    }
    insert_in_template(code, tags, 'style', template)
  end
  
  def insert_drag_drop(template)
    if (install_gem == nil)
      code = File.read(File.expand_path(Dir.pwd, '../../..') + '/public/js/Drag_Drop.js')
    else
      code = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'public/js/Drag_Drop.js'))
    end
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    insert_in_template(code, tags, 'script', template)
  end

  def load_yml
    I18n.enforce_available_locales = false if I18n.respond_to?('enforce_available_locales')
    files = []
    relative_path = 'config/locales/'
    if (install_gem == nil)
      new_path = relative_path
    else
      new_path = File.join(Gem.loaded_specs['ruql'].full_gem_path, relative_path)
    end
    
    Dir[new_path + '*.yml'].each do |path|
      if (install_gem == nil)
        files << File.expand_path(Dir.pwd, '../../..') + "/#{path}" 
      else
        files << path
      end
    end
    I18n.load_path = files
  end
  
  def yml_to_json(template)
    if (install_gem == nil)
      yml = File.read(File.expand_path(Dir.pwd, '../../..') + "/config/locales/#{@language.to_s}.yml")
    else
      yml = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, "config/locales/#{@language.to_s}.yml"))
    end
    data = YAML::load(yml)
    json = JSON.dump(data)
    code = %Q{
      i18n = #{json}
    }
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    insert_in_template(code, tags, 'script', template)
  end
  
  def translate(word, scope)
    I18n.translate word, :scope => scope, :locale => @language
  end
  
  def insert_defaultCSS
    @h.style do |s|
      if (install_gem == nil)
        s << File.read(File.expand_path(Dir.pwd, '../../../') + '/public/css/Style.css')
      else
        s << File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'public/css/Style.css'))             
      end
    end
  end
 
  def insert_defaultJS(totalPoints, template)
    if (install_gem == nil)
      js = File.read(File.expand_path(Dir.pwd, '../../../') + '/public/js/Validator.js')
    else
      js = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'public/js/Validator.js'))
    end
    code = %Q{
      data = #{@data.to_json};
      timestamp = #{Time.now.getutc.to_i}
      timestamp = timestamp.toString();
      language = '#{@language.to_s}';
      totalPoints = #{totalPoints};
      userPoints = 0;
      
      #{js}
    }
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    insert_in_template(code, tags, 'script', template)
  end
end
