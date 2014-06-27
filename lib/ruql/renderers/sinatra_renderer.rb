class SinatraRenderer
  require 'builder'
  require 'erb'
  require 'json'
  require 'sass'
  require 'yaml'
  require 'i18n'
  require 'locale'
  
  attr_reader :output, :output_erb, :data

  def initialize(quiz,options={})
    @css = options.delete('c') || options.delete('css')
    @js = options.delete('j') || options.delete('js')
    @html = options.delete('h') || options.delete('html')
    @show_solutions = options.delete('s') || options.delete('solutions')
    @template = options.delete('t') || options.delete('template')
    @output = ''
    @output_erb = ''
    @quiz = quiz
    @quiz_serialized_copy = YAML::load(YAML::dump(@quiz))
    @h = Builder::XmlMarkup.new(:target => @output, :indent => 2)
    @h_erb = Builder::XmlMarkup.new(:target => @output_erb, :indent => 2)
    @data = {}
    @size_inputs = []
    @size_divs = []
    @size_dd_divs = []
    @language = (Locale.current[0].language || 'en').to_sym
  end

  def render_quiz
    load_yml
    if @template
      render_with_template(@quiz, @h_erb, true) do
        @output_erb
      end
      render_with_template(@quiz_serialized_copy, @h) do
        @output
      end
    else
      # HTML with the quiz
      @h.html do
        @h.head do |h|
          @h.title @quiz.title
          insert_resources_head(h, @h)
        end
        @h.body do |b|
          render_questions
          insert_resources_body(b, @h)
        end
      end
      # ERB template for student's answers
      @h_erb.html do
        @h_erb.head do |h|
          @h_erb.title @quiz.title
          insert_resources_head(h, @h_erb)
        end
        @h_erb.body do |b|
          render_questions(true)
          insert_resources_body(b, @h_erb)
        end
      end
    end
    self
  end

  def render_with_template(qz, obj, erb=false)
    # local variables that should be in scope in the template 
    quiz = qz
    title = translate(:title, 'quiz') unless @title
    @css_custom = insert_css_js(true, @css, 'css', obj) if @css
    @bootstrap_css = insert_bootstrap_css
    @bootstrap_js = insert_bootstrap_js
    @js_custom = insert_css_js(true, @js, 'js', obj) if @js
    @jQuery = insert_jQuery('', true, obj)
    @mathjax = insert_mathjax(true, obj)
    @codemirror = insert_codemirror(true, obj)
    @codemirror_object = insert_codemirror_object(true, obj)
    @xregexp = insert_xregexp(true, obj)
    @i18n = yml_to_json(true, obj)
    @dragdrop = insert_drag_drop(true, obj)
    @context_menu = ''
    @context_menu_css = ''
    
    if (erb)
      render_questions(obj, true)
    else
      render_questions(obj)
    end
    
    @validation_js = insert_defaultJS(@quiz.points, true, obj)
    @sass = ''
    @sass = insert_sass('input') if !@size_inputs.empty?
    @sass << insert_sass('div') if !@size_divs.empty?
    @sass << insert_sass('dd_div') if !@size_dd_divs.empty?
    
    # the ERB template includes 'yield' where questions should go:
    output = ERB.new(IO.read(File.expand_path @template)).result(binding)
    
    if (erb)
      @output_erb = output
    else
      @output = output
    end
  end
  
  def content_form(quiz, obj, erb=false)
    obj.ol :class => 'questions' do
      quiz.questions.each_with_index do |q,i|
        raise "#{translate(:question, 'exceptions')}-#{i+1}: #{translate(:text, 'exceptions')}" if q.question_text == nil
        raise "#{translate(:question, 'exceptions')}-#{i+1}: #{translate(:answer, 'exceptions')}" if q.answers.length == 0
        case q
        when SelectMultiple then render_select_multiple(q, i, obj, erb)
        when MultipleChoice, TrueFalse then render_multiple_choice(q, i, obj, erb)
        when FillIn then render_fill_in(q, i, obj, erb)
        when Programming then render_programming(q, i, obj, erb)
        else
          raise "Unknown question type: #{q}"
        end
      end
    end
    obj.div :id => 'score', :class => 'score' do
    end
    obj.div :class => 'btn-footer' do
      insert_button('submit', translate(:submit, 'buttons'), 'btn btn-primary', true, obj)
      insert_button('reset', translate(:reset, 'buttons'), 'btn btn-info', obj)
      insert_button('deleteAnswers', translate(:delete, 'buttons'), 'btn btn-warning', obj)
      insert_button('deleteStorage', translate(:deleteAll, 'buttons'), 'btn btn-danger', obj)
    end
  end
  
  def render_questions(obj, erb=false)
    render_random_seed(obj)
    obj.form(:method => 'post', :action => '/quiz', :id => 'form') do
      if (erb)
        content_form(@quiz, obj, erb)
      else
        content_form(@quiz_serialized_copy, obj)
      end
    end
  end

  def erb_interpolation(id)
    @h_erb.b do
      @h_erb.div do |d|
        d << "<%= answers[:'#{id}'] || answers[:na] %>"
      end
    end
  end
  
  def insert_input(type, id, name, value, klass, answer, obj, erb=false)
    if (erb)
      erb_interpolation(id)
    else
      if (type == 'radio')
        obj.input(:type => type, :id => id, :name => name, :value => value, :class => klass) { |p| 
          p << answer.answer_text
          p << %Q{<br class="#{id}br">}
        }
      else
        obj.input(:type => type, :id => id, :name => name, :value => value, :class => klass) { |p| 
          p << answer.answer_text
          p << %Q{<br class="#{id}br">}
        }
      end
    end
    obj.div(:id => "#{id}r", :class => 'quiz') do
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
  
  def store_answers(answers, index, klass, id_klass, type_input, klass_input, obj, erb=false)
    id_answer = 1
    
    answers.each do |answer|
      @data[:"question-#{index}"][:answers]["#{id_klass}#{index + 1}-#{id_answer}".to_sym] = {:answer_text => answer.answer_text, :correct => answer.correct, 
                                                                                              :explanation => answer.explanation}
      if ((klass == DragDrop_MC) || (klass == DragDrop_SM))
        @data[:"question-#{index}"][:answers]["#{id_klass}#{index + 1}-#{id_answer}".to_sym][:type] = "Hash"
      else
        if (klass == SelectMultiple)
          insert_input(type_input, "#{id_klass}#{index + 1}-#{id_answer}", "#{id_klass}#{index + 1}-#{id_answer}", "#{answer.answer_text}", klass_input, answer, obj, erb)
        else
          insert_input(type_input, "#{id_klass}#{index + 1}-#{id_answer}", "#{id_klass}#{index + 1}", "#{answer.answer_text}", klass_input, answer, obj, erb) if !erb
        end
      end
      id_answer += 1
    end
    insert_input(type_input, "#{id_klass}#{index + 1}", "#{id_klass}#{index + 1}", nil, klass_input, nil, obj, erb) if (((klass == MultipleChoice) || (klass == TrueFalse)) && (erb))
  end
  
  def insert_drag_drop_keys(keys, id, q, index, klass, clone, obj, erb=false)
    obj.div(:id => "col1-q#{q}-#{id}", :class => 'col1') do |d|
      keys.each do |k|
        obj.a(:class => "btn btn-default btn-sm disabled button-q#{q}-#{id}", :draggable => 'false') do |b|
          b << k
        end
        obj.br
      end
    end
    obj.div(:id => "col2-q#{q}-#{id}", :class => 'col2') do 
      keys.length.times do |i|
        if (id =~ /qddmc/)
          if (erb)
            erb_interpolation("#{id}#{index + 1}-#{i + 1}")
          else
            obj.input(:id => "#{id}#{index + 1}-#{i + 1}", :name => "#{id}#{index + 1}-#{i + 1}", :type => 'text', :class => klass, :ondrop => "drop(event, '#{id}#{index + 1}-#{i + 1}', #{clone})", 
:ondragover => "allowDrop(event)")
          end
          obj.br
        elsif (id =~ /qddsm/)
          if (erb)
            erb_interpolation("#{id}#{index + 1}-#{i + 1}")
            obj.br
          else
            obj.div(:id => "#{id}#{index + 1}-#{i + 1}", :type => 'text', :class => klass, :ondrop => "drop(event, '#{id}#{index + 1}-#{i + 1}', #{clone})", :ondragover => "allowDrop(event)") do end
            obj.input(:type => 'hidden', :name => "#{id}#{index + 1}-#{i + 1}")
          end
        end
      end
    end
  end
  
  def insert_drag_drop_values(d, values, id, index, obj)
    counter = 1
    d << translate(:answers, '') + ": " if id =~ /qddsm/
    values.each do |v|
      obj.a(:id => "#{id}a#{index + 1}-#{counter}", :name => "#{id}a#{index + 1}-#{counter}", :class => "btn btn-default btn-sm button-#{id}", :draggable => 'true', :ondragstart => 'drag(event)') do 
|b|
        b << v           
      end
      counter += 1
      obj.br if id =~ /qddmc/
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
  
  def render_multiple_choice(q, index, obj, erb=false)
    render_question_text(q, index, obj, erb) do
      answers =
        if q.class == TrueFalse then q.answers.sort.reverse # True always first
        elsif q.randomize then q.answers.sort_by { rand }
        else q.answers
        end
      obj.ol :class => 'answers' do
        
        if (q.class == DragDrop_MC)
          keys, values = [], []
          get_drag_drop_answers(answers, keys, values)
          values.sort_by! { rand }
        end
        
        # Store answers for question-index
        ((q.class == MultipleChoice) || (q.class == TrueFalse)) ? id_klass = "qmc" : id_klass = "qddmc"
        store_answers(answers, index, q.class, id_klass, 'radio', 'select', obj, erb)
        
        if (q.class == DragDrop_MC)
          obj.div do
            insert_drag_drop_keys(keys, 'qddmc', index + 1, index, "dragdropmc input-qddmc", true, obj, erb)
            obj.div(:id => "col3-q#{index}-qddmc", :class => 'col3') do |d|
              insert_drag_drop_values(d, values, 'qddmc', index, obj) if !erb
            end
          end
          obj.div(:class => 'clear-qdd')
        end
        obj.br
      end
    end
    question_comment(q, obj)
    q.class == MultipleChoice ? flag = true : flag = false
    insert_buttons_each_question(index, flag, obj)
    self
  end

  def render_select_multiple(q, index, obj, erb=false)
    render_question_text(q, index, obj, erb) do
      answers =
      if q.randomize then q.answers.sort_by { rand }
      else q.answers
      end
      obj.ol :class => 'answers' do
        
        if (q.class == DragDrop_SM)
          keys, values = [], []
          get_drag_drop_answers(answers, keys, values)
          values.flatten!.sort_by! { rand }
        end
        
        # Store answers for question-index
        q.class == SelectMultiple ? id_klass = "qsm" : id_klass = "qddsm"
        store_answers(answers, index, q.class, id_klass, 'checkbox', 'check', obj, erb)
        
        if (q.class == DragDrop_SM)
          max = get_max_length_select_multiple_div(answers)
          @size_dd_divs << max
          
          obj.div do
            insert_drag_drop_keys(keys, 'qddsm', index + 1, index, "dragdropsm size-#{max}", false, obj, erb)
            obj.div(:class => 'clear-qdd')
            obj.br if !erb
            obj.div(:id => "answers-q#{index + 1}-qddsm", :ondrop => "drop(event, 'answers-q#{index + 1}-qddsm', false)", :ondragover => "allowDrop(event)") do |d|
              insert_drag_drop_values(d, values, 'qddsm', index, obj)
            end if !erb
          end
          
        end
        obj.br if !erb
      end
    end
    question_comment(q, obj)
    q.class == SelectMultiple ? flag = true : flag = false
    insert_buttons_each_question(index, flag, obj)
    self
  end
  
  def type_answer_fill_in(answer, item, idx, id_answer, class_question) 
    if (item.class == Regexp)
      ans = item
      type = 'Regexp'
    elsif (item.class == String)
      ans = item.downcase
      type = 'String'
    elsif (item.class == Fixnum)
      ans = item
      type = 'Fixnum'
    else
      ans = item.to_javascript
      type = 'JS'
    end
    @data[:"question-#{idx}"][:answers]["#{class_question}#{idx + 1}-#{id_answer}".to_sym] = {:answer_text => ans, :correct => answer.correct, 
                                                                                              :explanation => answer.explanation, :type => type}
  end
  
  def render_fill_in(q, idx, obj, erb=false)
    render_question_text(q, idx, obj, erb) do
      
      question_comment(q, obj)
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
      insert_buttons_each_question(idx, obj)
    end
  end
  
  def render_programming(q, index, obj, erb=false)
    render_question_text(q, index, obj, erb) do
      answer = q.answers[0]
      obj.ol :class => 'answers' do
        # Store answers for question-index
        @data[:"question-#{index}"][:answers]["qp#{index + 1}-1".to_sym] = {:answer_text => answer.answer_text.to_javascript, :correct => answer.correct, 
                                                                            :explanation => answer.explanation, :type => q.language}
        if (erb)
          erb_interpolation("qp#{index + 1}-1")
        else
          obj.textarea(:id => "qp#{index + 1}-1", :name => "qp#{index + 1}-1", :class =>'programming', :rows => 5, :cols => 80, :height => q.height, :width => q.width, :placeholder => 
"#{translate(:placeholder, 'questions')}...") do
          end
          obj.br
          obj.br
        end
      end
    end
    question_comment(q, obj)
    insert_buttons_each_question(index, obj)
    self
  end
  
  def hyphens_to_inputs(question, index, erb=false)
    hyphen = question.question_text.scan(/(?<!\\)---+/)
    hyphen.length.times do |i|
      nHyphen = hyphen[i].count('-')
      @size_inputs << nHyphen
      if (erb)
        input = %Q{<b><%= answers[:'qfi#{index + 1}-#{i + 1}'] || answers[:na] %></b>} if question.class == FillIn
        input = %Q{<b><%= answers[:'qddfi#{index + 1}-#{i + 1}'] || answers[:na] %></b>} if question.class == DragDrop_FI
      else 
        input = %Q{<input type="text" id="qfi#{index + 1}-#{i + 1}" name="qfi#{index + 1}-#{i + 1}" class="fillin size-#{nHyphen}"></input>} if question.class == FillIn
        input = %Q{<input id="qddfi#{index + 1}-#{i + 1}" name="qddfi#{index + 1}-#{i + 1}" class="dragdropfi size-#{nHyphen}" ondrop="drop(event,'qddfi#{index + 1}-#{i + 1}', 
        true)" ondragover="allowDrop(event)"></input>} if question.class == DragDrop_FI
      end
      question.question_text.sub!(/(?<!\\)---+/, input)
    end
    question.question_text.gsub!(/\\-/, '-')
    
    if (question.class == FillIn)
      question.question_text << %Q{<div id="qfi#{index + 1}-#{hyphen.length}r" class="quiz"></div></br></br>} 
    
    elsif (question.class == DragDrop_FI)
      if (!erb)
        question.question_text << "<br/><br/>"
        question.question_text << "<div> #{translate(:answers, '')}: "
        question.answers[0].answer_text.each_with_index do |a, i|
          @size_divs << a.to_s.length
          question.question_text << %Q{<a class="dragdropfi size-#{a.to_s.length} btn btn-default btn-sm" id="qddfia#{i + 1}-#{i + 1}" draggable="true" 
          ondragstart="drag(event)">#{a}</a>&nbsp&nbsp}
        end
      end
      question.question_text << "<div/>"
      if (erb)
        question.question_text << "</br>"
      else
        question.question_text << "</br></br>"
      end
    else 
      question.raw? ? question.question_text : question.question_text << "<br></br>"
    end
  end
  
  def render_question_text(question, index, obj, erb=false)
    html_args = {
      :id => "question-#{index}",
      :class => ['question', question.class.to_s.downcase, (question.multiple ? 'multiple' : '')]
        .join(' ')
    }
    obj.li html_args  do
      obj.div :class => 'quiz text' do |d|
        questionText = question.question_text.clone
        qtext = "[#{question.points} point#{'s' if question.points>1}] " <<
          ('Select ALL that apply: ' if question.multiple).to_s <<
          hyphens_to_inputs(question, index, erb)
          
          # Hash with questions and all posibles answers
          if ((question.class == FillIn) || (question.class == DragDrop_FI))
            @data[html_args[:id].to_sym] = {:question_text => questionText, :answers => {}, :points => question.points, 
                                            :order => question.order, :question_comment => question.question_comment}
          elsif (question.class == Programming)
            @data[html_args[:id].to_sym] = {:question_text => questionText, :answers => {}, :points => question.points, 
                                            :question_comment => question.question_comment, :language => question.language,
                                            :height => question.height, :width => question.width}
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

  def render_random_seed(obj)
    obj.comment! "Seed: #{@quiz.seed}"
  end
  
  def question_comment(q, obj)
    obj.p :class => 'comment' do |p|
      p << q.question_comment + "<br></br>"
    end if (q.question_comment != "")
  end
  
  def insert_button(id, name, type, server=false, obj)
    if (server)
      obj.button(:type => 'submit', :id => id, :class => type) do |b|
        b << name
      end
    else
      obj.a(:id => id, :class => type) do |b|
        b << name
      end
    end
  end
  
  def insert_buttons_each_question(index, flag=false, obj)
    obj.br do
    end
  end
  
  def insert_resources_head(h, obj)
    insert_defaultCSS(obj)
    insert_html(h) if @html
    insert_css_js(false, @css, 'css', obj) if @css
    insert_mathjax(false, obj)
    insert_codemirror(false, obj)
  end
  
  def insert_resources_body(b, obj)
    insert_jQuery(b, false, obj)
    insert_defaultJS(@quiz.points, false, obj)
    insert_xregexp(false, obj)
    insert_css_js(false, @js, 'js', obj) if @js
    insert_codemirror_object(false, obj)
    insert_drag_drop(false, obj)
    yml_to_json(false, obj)
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
  
  def insert_css_js(template, attr, type, obj=nil)
    code = ""
    if (attr.class == Array)
      if (template)
        attr.each do |file|
          code << %Q{<link rel="stylesheet" type="text/css" href="#{File.expand_path(file)}" />\n} if type == 'css'
          code << %Q{<script type="text/javascript" src="#{File.expand_path(file)}"></script>\n} if type == 'js'
        end
      else
        attr.each do |file|
          obj.link(:rel => 'stylesheet', :type =>'text/css', :href => File.expand_path(file)) if type == 'css'
          obj.script(:type => 'text/javascript', :src => "#{File.expand_path(file)}") do
          end if type == 'js'
        end
      end
    else
      if (template)
        code << %Q{<link rel="stylesheet" type="text/css" href="#{File.expand_path(attr)}" />} if type == 'css'
        code << %Q{<script type="text/javascript" src="#{File.expand_path(@js)}"></script>\n} if type == 'js'
      else
        obj.link(:rel => 'stylesheet', :type =>'text/css', :href => File.expand_path(attr)) if type == 'css'
        obj.script(:type => 'text/javascript', :src => "#{File.expand_path(@js)}") do
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
  
  def insert_jQuery(h, template, obj=nil)
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
      obj.script(:type => 'text/javascript') do |j|
        j << jQuery2
      end
      h << "<!--[if lt IE 8]>"
      obj.script(:type => 'text/javascript') do |j|
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
  
  def insert_in_template(code, tags, tag, template, obj)
    if (template)
      tags
    else
      if (tag == 'style')
        obj.style(:type =>'text/css') do |c|
          c << code
        end
      elsif (tag == 'script')
        obj.script(:type =>'text/javascript') do |j|
          j << code
        end
      end
    end
  end
  
  def insert_xregexp(template, obj=nil)
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
    insert_in_template(code, tags, 'script', template, obj)
  end
  
  def insert_mathjax(template, obj=nil)
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
      obj.script(:type => 'text/javascript', :src => "https://c328740.ssl.cf1.rackcdn.com/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML") do
      end
      obj.script(:type => 'text/javascript') do |j|
        j << config
      end
    end
  end
  
  def insert_codemirror(template, obj=nil)
    if (install_gem == nil)
      css = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/CodeMirror-4.1.0/css/codemirror.css')
      js = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/CodeMirror-4.1.0/js/codemirror.min.js')
      mode_js = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/CodeMirror-4.1.0/mode/javascript/javascript.js')
    else
      css = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/CodeMirror-4.1.0/css/codemirror.css'))
      js = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/CodeMirror-4.1.0/js/codemirror.min.js'))
      mode_js = File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'vendor/assets/CodeMirror-4.1.0/mode/javascript/javascript.js'))
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
      obj.style(:type =>'text/css') do |s|
        s << css
      end
      obj.script(:type => 'text/javascript') do |j|
        j << js
      end
      obj.script(:type => 'text/javascript') do |j|
        j << mode_js
      end
    end
  end
  
  def insert_codemirror_object(template, obj=nil)
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
    insert_in_template(code, tags, 'script', template, obj)
  end

  def insert_drag_drop(template, obj=nil)
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
    insert_in_template(code, tags, 'script', template, obj)
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
  
  def yml_to_json(template, obj=nil)
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
    insert_in_template(code, tags, 'script', template, obj)
  end
  
  def translate(word, scope)
    I18n.translate word, :scope => scope, :locale => @language
  end
  
  def insert_defaultCSS(obj)
    obj.style do |s|
      if (install_gem == nil)
        s << File.read(File.expand_path(Dir.pwd, '../../../') + '/public/css/Style.css')
      else
        s << File.read(File.join(Gem.loaded_specs['ruql'].full_gem_path, 'public/css/Style.css'))             
      end
    end
  end
 
  def insert_defaultJS(totalPoints, template, obj=nil)
    code = %Q{
      data = #{@data.to_json};
      timestamp = #{Time.now.getutc.to_i}
      timestamp = timestamp.toString();
      language = '#{@language.to_s}';
      totalPoints = #{totalPoints};
      userPoints = 0;
      
      function storeAnswers() {
        if(typeof(Storage) !== undefined) {
          tmp = {}
          
          inputText = $('input:text').filter(function() { return $(this).val() != ""; });
          for (i = 0; i < inputText.length; i++) {
            idAnswer = inputText[i].id;
            tmp[idAnswer] = inputText[i].value;
          }
          
          inputRadioCheckBox = $('input:checked');
          for (i = 0; i < inputRadioCheckBox.length; i++) {
            idAnswer = inputRadioCheckBox[i].id;
            nquestion = parseInt(idAnswer.split('-')[0].substr(3)) - 1;
            tmp[idAnswer] = data["question-" + nquestion.toString()]['answers'][idAnswer]['answer_text'];
          }
          
          $.each(id_textareas, function(k,v) {
            tmp[k] = id_textareas[k]['editor'].getValue();
        });
        
        localStorage.setItem(timestamp, JSON.stringify(tmp));
  }
        else {
          alert("El navegador no soporta almacenamiento de respuestas");
        }
      }
      
      function loadAnswers() {
        if ((localStorage.length != 0) && (localStorage[timestamp] !== undefined)) {
          tmp = JSON.parse(localStorage[timestamp]);
          for (x in tmp) {
            if ((x.match(/qfi/)) || (x.match(/qddfi/)) || (x.match(/qddmc/)))
              $("#" + x.toString()).val(tmp[x.toString()]);
            else if (x.match(/qp/))
              id_textareas[x]['editor'].setValue(tmp[x]);
            else
              $("#" + x.toString()).attr('checked', 'checked');
            }
          }
        }
        
        function deleteAnswers(all, flag) {
          if (all) {
            localStorage.clear();
            if (flag)
              alert("Almacenamiento borrado");
            }
          else {
            localStorage.removeItem(timestamp);
            if (flag)
              alert("Respuestas borradas");
            }
          }
          
          function reload() {
            window.location.reload();
      }
      
      function clearTextarea() {
        areas = $('textarea');
        $.each(areas, function(i, v) {
          if (v.value.match(/^\s+$/))
            v.value = '';
          });
      }
      
      function trimButtons() {
        buttons = $('a');
        $.each(buttons, function(i, v) {
          v.textContent = v.textContent.trim();
        });
      }
      
      $("#reset").click(function() {
        reload();
      });
      
      $("#deleteAnswers").click(function() {
        deleteAnswers(false, 1);
        reload();
      });
      
      $("#deleteStorage").click(function() {
        deleteAnswers(true, 1);
        reload();
      });
      
      $("input").blur(function(){
        storeAnswers();
      });
      
      $(document).ready(function() {
        clearTextarea();
        trimButtons();
        loadAnswers();
      });
    }
    tags = %Q{
      <script type="text/javascript">
      #{code}
      </script>
    }
    insert_in_template(code, tags, 'script', template, obj)
  end
end
