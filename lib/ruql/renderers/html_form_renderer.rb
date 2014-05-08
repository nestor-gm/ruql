class HtmlFormRenderer
  require 'builder'
  require 'erb'
  require 'json'
  require 'sass'
  require 'yaml'
  require 'i18n'
  require 'locale'
  ENV['environment'] ||= 'production'
  
  attr_reader :output

  def initialize(quiz,options={})
    @css = options.delete('c') || options.delete('css')
    @js = options.delete('j') || options.delete('js')
    @html = options.delete('h') || options.delete('html')
    @show_solutions = options.delete('s') || options.delete('solutions')
    @template = options.delete('t')  ||
      options.delete('template') ||
      if (ENV['test'] == 'production')
        File.join(Gem.loaded_specs['ruql'].full_gem_path, 'templates/htmlform.html.erb')
      else
        'templates/htmlform.html.erb'
      end
    @output = ''
    @quiz = quiz
    @h = Builder::XmlMarkup.new(:target => @output, :indent => 2)
    @data = {}
    @size_inputs = []
    @size_divs = []
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
    @css_custom = insert_css(true) if @css
    @bootstrap_css = insert_bootstrap_css
    @bootstrap_js = insert_bootstrap_js
    @js_custom = insert_js(true) if @js
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
    
    # the ERB template includes 'yield' where questions should go:
    output = ERB.new(IO.read(File.expand_path @template)).result(binding)
    @output = output
  end
    
  def render_questions
    render_random_seed
    @h.form(:id => 'form') do
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
  end

  def render_multiple_choice(q,index)
    render_question_text(q, index) do
      answers =
        if q.class == TrueFalse then q.answers.sort.reverse # True always first
        elsif q.randomize then q.answers.sort_by { rand }
        else q.answers
        end
      @h.ol :class => 'answers' do
        id_answer = 1
        
        if (q.class == DragDrop_MC)
          keys, values = [], []
          answers.each do |a|
            keys << a.answer_text.keys[0].to_s
            values << a.answer_text.values[0].to_s
          end
          values.sort_by! { rand }
        end
        
        answers.each do |answer|
          # Store answers for question-index
          if (q.class == MultipleChoice)
            @data[:"question-#{index}"][:answers]["qmc#{index + 1}-#{id_answer}".to_sym] = {:answer_text => answer.answer_text, :correct => answer.correct, 
                                                                                            :explanation => answer.explanation} 
          else # DragDrop_MC
            @data[:"question-#{index}"][:answers]["qddmc#{index + 1}-#{id_answer}".to_sym] = {:answer_text => answer.answer_text, :correct => answer.correct, 
                                                                                              :explanation => answer.explanation, :type => "Hash"}
          end
          
          if (q.class == MultipleChoice)
            @h.input(:type => 'radio', :id => "qmc#{index + 1}-#{id_answer}", :name => "qmc#{index + 1}", :class => 'select') { |p| 
              p << answer.answer_text
              p << "<br class=qmc#{index + 1}-#{id_answer}br>"
            }
            @h.div(:id => "qmc#{index + 1}-#{id_answer}r", :class => 'quiz') do
            end
          end
          id_answer += 1
        end
        
        if (q.class == DragDrop_MC)
          @h.div do
            @h.div(:id => 'col1', :class => 'col1') do |d|
              keys.each do |k|
                @h.button(:class => 'btn btn-default btn-sm disabled button-qddmc', :draggable => 'false') do |b|
                  b << k
                end
                @h.br
              end
            end
            @h.div(:id => 'col2', :class => 'col2') do 
              keys.length.times do |i|
                @h.input(:id => "qddmc#{index + 1}-#{i + 1}", :type => 'text', :class => "dragdropmc input-qddmc", :ondrop => "drop(event, 'qddmc#{index + 1}-#{i + 1}', true)", :ondragover => "allowDrop(event)")
                @h.br
              end
            end
            @h.div(:id => 'col3', :class => 'col3') do |d|
              counter = 1
              values.each do |v|
                @h.button(:id => "qddmca#{index + 1}-#{counter}", :class => 'btn btn-default btn-sm button-qddmc', :draggable => 'true', :ondragstart => 'drag(event)') { |b|
                  b << v                                                                                                                                                                      }
                counter += 1
                @h.br
              end
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
        id_answer = 1
        
        if (q.class == DragDrop_SM)
          keys, values = [], []
          answers.each do |a|
            keys << a.answer_text.keys[0].to_s
            a.answer_text.each_value do |v|
              values << v
            end
          end
          values.flatten!.sort_by! { rand }
        end
        
        answers.each do |answer|
          # Store answers for question-index
          if (q.class == SelectMultiple)
            @data[:"question-#{index}"][:answers]["qsm#{index + 1}-#{id_answer}".to_sym] = {:answer_text => answer.answer_text, :correct => answer.correct, 
                                                                                            :explanation => answer.explanation}
          else # DragDrop_SM
            @data[:"question-#{index}"][:answers]["qddsm#{index + 1}-#{id_answer}".to_sym] = {:answer_text => answer.answer_text, :correct => answer.correct, 
                                                                                            :explanation => answer.explanation, :type => "Hash"}
          end
          
          if (q.class == SelectMultiple)
            @h.input(:type => 'checkbox', :id => "qsm#{index + 1}-#{id_answer}", :class => 'check') { |p| 
              p << answer.answer_text
              p << "<br class=qsm#{index + 1}-#{id_answer}br>"
            }
            @h.div(:id => "qsm#{index + 1}-#{id_answer}r", :class => 'quiz') do
            end
          end
          id_answer += 1
        end
        
        if (q.class == DragDrop_SM)
          @h.div do
            @h.div(:id => 'col1', :class => 'col1') do |d|
              keys.each do |k|
                @h.button(:class => 'btn btn-default btn-sm disabled button-qddsm', :draggable => 'false') do |b|
                  b << k
                end
                @h.br
              end
            end
            @h.div(:id => 'col2', :class => 'col2sm') do 
              keys.length.times do |i|
                @h.div(:id => "qddsm#{index + 1}-#{i + 1}", :type => 'text', :class => "dragdropsm", :ondrop => "drop(event, 'qddsm#{index + 1}-#{i + 1}', false)", :ondragover => "allowDrop(event)") do end
              end
            end
            @h.div(:class => 'clear-qdd')
            @h.br
            @h.div(:id => "answers_qddsm", :ondrop => "drop(event, 'answers_qddsm', false)", :ondragover => "allowDrop(event)") do |d|
              counter = 1
              d << translate(:answers, '') + ": " 
              values.each do |v|
                @h.button(:id => "qddsma#{index + 1}-#{counter}", :class => 'btn btn-default btn-sm button-qddsm', :draggable => 'true', :ondragstart => 'drag(event)') do |b|
                  b << v
                end
                counter += 1
              end
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
    else
      ans = item.to_javascript
      type = 'JS'
    end
    @data[:"question-#{idx}"][:answers]["#{class_question}#{idx + 1}-#{id_answer}".to_sym] = {:answer_text => ans, :correct => answer.correct, 
                                                                                              :explanation => answer.explanation, :type => type}
  end
  
  def render_fill_in(q, idx)
    render_question_text(q, idx) do
      
      question_comment(q)
      if (q.class == FillIn)
        class_question = "qfi"
      elsif (q.class == DragDrop_FI)
        class_question = "qddfi"
      end
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
        @h.textarea(:id => "qp#{index + 1}-1", :class =>'programming', :rows => 5, :cols => 80, :height => q.height, :width => q.width, :placeholder => "#{translate(:placeholder, 'questions')}...") do
        end
        @h.br
        @h.br
      end
    end
    question_comment(q)
    insert_buttons_each_question(index)
    self
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
          if question.class == FillIn
            hyphen = question.question_text.scan(/(?<!\\)---+/)
            hyphen.length.times { |i|
                                 nHyphen = hyphen[i].count('-')
                                 @size_inputs << nHyphen
                                 input = %Q{<input type="text" id="qfi#{index + 1}-#{i + 1}" class="fillin size-#{nHyphen}"></input>}
                                 question.question_text.sub!(/(?<!\\)---+/, input)
                                }
            question.question_text.gsub!(/\\-/, '-')
            question.question_text << %Q{<div id="qfi#{index + 1}-#{hyphen.length}r" class="quiz"></div></br></br>}
            
          elsif question.class == DragDrop_FI
            hyphen = question.question_text.scan(/(?<!\\)---+/)
            hyphen.length.times { |i|
                                 nHyphen = hyphen[i].count('-')
                                 @size_inputs << nHyphen
                                 attr = %Q{id="qddfi#{index + 1}-#{i + 1}" class="dragdropfi size-#{nHyphen}" ondrop="drop(event,'qddfi#{index + 1}-#{i + 1}', true)" ondragover="allowDrop(event)"}
                                 question.question_text.sub!(/(?<!\\)---+/, "<input #{attr}></input>")
                                }
            question.question_text.gsub!(/\\-/, '-')
            question.question_text << "<br/><br/>"
            question.question_text << "<div> #{translate(:answers, '')}: "
            question.answers[0].answer_text.each_with_index do |a, i|
              @size_divs << a.to_s.length
              question.question_text << %Q{<button class="dragdropfi size-#{a.to_s.length} btn btn-default btn-sm" id="qddfia#{i + 1}-#{i + 1}" draggable="true" ondragstart="drag(event)">#{a}</button>&nbsp&nbsp}
            end
            question.question_text << "<div/>"
            question.question_text << "</br></br>"
          else 
            if (question.raw?)
              question.question_text
            else
              question.question_text << "<br></br>"
            end
          end
          
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

  def render_random_seed
    @h.comment! "Seed: #{@quiz.seed}"
  end
  
  def question_comment(q)
    @h.p :class => 'comment' do |p|
      p << q.question_comment + "<br></br>"
    end if (q.question_comment != "")
  end
  
  def insert_button(id, name, type)
    @h.button(:type => 'button', :id => id, :class => type) do |b|
      b << name
    end
  end
  
  def insert_buttons_each_question(index, flag=false)
    insert_button("show-answer-q-#{index}", translate(:show, 'buttons'), 'btn btn-success btn-sm') if flag
    insert_button("q-#{index}", translate(:submit, 'buttons'), 'btn btn-primary btn-sm')
    @h.br do
    end
  end
  
  def insert_resources_head(h)
    insert_defaultCSS
    insert_html(h) if @html
    insert_contextMenu_css(false)
    insert_css(false) if @css
    insert_mathjax(false)
    insert_codemirror(false)
  end
  
  def insert_resources_body(b)
    insert_jQuery(b, false)
    insert_contextMenu(false)
    insert_xregexp(false)
    insert_js(false) if @js
    insert_codemirror_object(false)
    insert_drag_drop(false)
    yml_to_json(false)
    insert_defaultJS(@quiz.points, false)
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
  
  def insert_css(template)
    code = ""
    if (@css.class == Array)
      if (template)
        @css.each do |file|
          code << %Q{<link rel="stylesheet" type="text/css" href="#{File.expand_path(file)}" />\n}
        end
      else
        @css.each do |file|
          @h.link(:rel => 'stylesheet', :type =>'text/css', :href => File.expand_path(file))
        end
      end
    else
      if (template)
        code << %Q{<link rel="stylesheet" type="text/css" href="#{File.expand_path(@css)}" />}
      else
        @h.link(:rel => 'stylesheet', :type =>'text/css', :href => File.expand_path(@css))
      end
    end
    code if template
  end
  
  def insert_sass(tag)
    sass = ""
    if (tag == 'input')
      @size_inputs.uniq.sort.each { |sz| sass << "input.size-#{sz.to_s} { width: #{sz-(sz*0.3)}em}"}
    else
      @size_divs.uniq.sort.each { |sz| sass << "div.size-#{sz.to_s} { width: #{sz-(sz*0.3)}em; display: inline;}"}
    end
    engine = Sass::Engine.new(sass, :syntax => :scss)
    engine.options[:style] = :compact
    engine.render
  end
  
  def insert_jQuery(h, template)
    jQuery2 = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/jQuery/jquery-2.1.0.min.js')
    jQuery1 = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/jQuery/jquery-1.11.0.min.js')
    
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
    %Q{
      <style type="text/css">
        #{File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/Bootstrap-3.1.1/css/bootstrap.min.css')}
      </style>
    }
  end
  
  def insert_bootstrap_js
    %Q{
      <script type="text/javascript">
        #{File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/Bootstrap-3.1.1/js/bootstrap.min.js')}
      </script>
    }
  end
  
  def insert_xregexp(template)
    code = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/XRegexp-2.0.0/xregexp-min.js')
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    
    if (template)
      tags
    else
      @h.script(:type => 'text/javascript') do |j|
        j << code
      end
    end
  end
  
  def insert_mathjax(template)
    config = File.read(File.expand_path(Dir.pwd, '../../..') + '/public/js/MathJax_config.js')
    if (template)
      code = %Q{
        <script type="text/javascript" src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
        </script>
        <script type="text/javascript">
         #{config}
        </script>
      }
    else
      @h.script(:type => 'text/javascript', :src => "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML") do
      end
      @h.script(:type => 'text/javascript') do |j|
        j << config
      end
    end
  end
  
  def insert_codemirror(template)
    css = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/CodeMirror-4.1.0/css/codemirror.css')
    js = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/CodeMirror-4.1.0/js/codemirror.min.js')
    mode_js = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/CodeMirror-4.1.0/mode/javascript/javascript.js')
    
    if (template)
      code = %Q{
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
    code = File.read(File.expand_path(Dir.pwd, '../../..') + '/public/js/CodeMirror_Object.js')
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    
    if (template)
      tags
    else
      @h.script(:type => 'text/javascript') do |j|
        j << code
      end
    end
  end
  
  def insert_contextMenu(template)
    code = %Q{
      #{File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/ContextJS/js/context.js')}
      #{File.read(File.expand_path(Dir.pwd, '../../..') + '/public/js/ContextJS_init.js')}
      
      $(document).mousedown(function(e){ 
        if( e.button == 2 ) {
          id_answer = e.toElement.id;
          if (id_answer.match(/^qfi/)) {
            numQuestion = parseInt(id_answer.split('-')[0].slice(3)) - 1;
            try {
              if (data["question-" + numQuestion.toString()]['answers'][id_answer]['type'] != "JS") {
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
    if (template)
      tags
    else
      @h.script(:type => 'text/javascript') do |j|
        j << code
      end
    end
  end
  
  def insert_contextMenu_css(template)
    code = File.read(File.expand_path(Dir.pwd, '../../..') + '/vendor/assets/ContextJS/css/context.standalone.css')
    tags = %Q{
      <style type="text/css">
        #{code}
      </style>
    }
    
    if (template)
      tags
    else
      @h.style(:type =>'text/css') do |c|
        c << code
      end
    end
  end
  
  def insert_drag_drop(template)
    code = File.read(File.expand_path(Dir.pwd, '../../..') + '/public/js/Drag_Drop.js')
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    
    if (template)
      tags
    else
      @h.script(:type => 'text/javascript') do |j|
        j << code
      end
    end
  end
  
  def insert_js(template)
    code = ""
    if (@js.class == Array)
      if (template)
        @js.each do |file|
          code << %Q{<script type="text/javascript" src="#{File.expand_path(file)}"></script>\n}
        end
      else
        @js.each do |file|
            @h.script(:type => 'text/javascript', :src => "#{File.expand_path(file)}") do
            end
        end
      end
    else
      if (template)
        code << %Q{<script type="text/javascript" src="#{File.expand_path(@js)}"></script>\n}
      else
        @h.script(:type => 'text/javascript', :src => "#{File.expand_path(@js)}") do
        end
      end
    end
    code if template
  end
  
  def load_yml
    I18n.enforce_available_locales = false if I18n.respond_to?('enforce_available_locales')
    files = []
    Dir['config/locales/*.yml'].each { |path| files << File.expand_path(Dir.pwd, '../../..') + "/#{path}" }
    I18n.load_path = files
  end
  
  def yml_to_json(template)
    yml = File.read(File.expand_path(Dir.pwd, '../../..') + "/config/locales/#{@language.to_s}.yml")
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
    
    if (template)
      tags
    else
      @h.script(:type => 'text/javascript') do |j|
        j << code
      end
    end
  end
  
  def translate(word, scope)
    I18n.translate word, :scope => scope, :locale => @language
  end
  
  def insert_defaultCSS
    @h.style do |s|
      s << File.read(File.expand_path(Dir.pwd, '../../../') + '/public/css/Style.css')
    end
  end
 
  def insert_defaultJS(totalPoints, template)
    code = %Q{
      data = #{@data.to_json};
      timestamp = #{Time.now.getutc.to_i}
      timestamp = timestamp.toString();
      language = '#{@language.to_s}';
      totalPoints = #{totalPoints};
      userPoints = 0;
      
      #{File.read(File.expand_path(Dir.pwd, '../../../') + '/public/js/Validator.js')}
    }
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    
    if (template)
      tags
    else
      @h.script(:type => 'text/javascript') do |j|
        j << code
      end
    end
  end
end
