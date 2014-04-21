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
    @template = options.delete('t') ||
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
    @js_custom = insert_js(true) if @js
    @jQuery = insert_jQuery('', true)
    @mathjax = insert_mathjax(true)
    @xregexp = insert_xregexp(true)
    @i18n = yml_to_json
    @dragdrop = insert_drag_drop
   
    render_questions
    @validation_js = insert_defaultJS(@quiz.points)
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
          begin
            case q
            when SelectMultiple then render_select_multiple(q,i)
            when MultipleChoice, TrueFalse then render_multiple_choice(q,i)
            when FillIn then render_fill_in(q, i)
            else
              raise "Unknown question type: #{q}"
            end
          rescue Exception => e
            $stderr.puts "*** #{e.class} *** #{translate(:syntax, 'exceptions')}"
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
        answers.each do |answer|
          # Store answers for question-index
          @data[:"question-#{index}"][:answers]["qmc#{index + 1}-#{id_answer}".to_sym] = {:answer_text => answer.answer_text, :correct => answer.correct, 
                                                                                          :explanation => answer.explanation} 
                  
          @h.input(:type => 'radio', :id => "qmc#{index + 1}-#{id_answer}", :name => "qmc#{index + 1}", :class => 'select') { |p| 
            p << answer.answer_text
            p << "<br class=qmc#{index + 1}-#{id_answer}br>"
          }
          @h.div(:id => "qmc#{index + 1}-#{id_answer}r", :class => 'quiz') do
          end
          id_answer += 1
        end
        @h.br
      end
    end
    question_comment(q)
    insert_buttons_each_question(index)
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
        answers.each do |answer|
          # Store answers for question-index
          @data[:"question-#{index}"][:answers]["qsm#{index + 1}-#{id_answer}".to_sym] = {:answer_text => answer.answer_text, :correct => answer.correct, 
                                                                                          :explanation => answer.explanation}
        
          @h.input(:type => 'checkbox', :id => "qsm#{index + 1}-#{id_answer}", :class => 'check') { |p| 
            p << answer.answer_text
            p << "<br class=qsm#{index + 1}-#{id_answer}br>"
          }
          @h.div(:id => "qsm#{index + 1}-#{id_answer}r", :class => 'quiz') do
          end
          id_answer += 1
        end
        @h.br
      end
    end
    question_comment(q)
    insert_buttons_each_question(index)
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
      flag_js_qdd = false
      
      question_comment(q)
      if (q.class == FillIn)
        class_question = "qfi"
      elsif (q.class == DragDrop)
        class_question = "qdd"
        flag_js_qdd = true
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
        flag_js_qdd = true if (a.class == JS)
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
      insert_buttons_each_question(idx, flag_js_qdd)
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
          if question.class == FillIn
            hyphen = question.question_text.scan(/(?<!\\)---+/)
            hyphen.length.times { |i|
                                 nHyphen = hyphen[i].count('-')
                                 @size_inputs << nHyphen
                                 question.question_text.sub!(/(?<!\\)---+/, "<input type=text id=qfi#{index + 1}-#{i + 1} class='fillin size-#{nHyphen}'></input>")
                                }
            question.question_text.gsub!(/\\-/, '-')
            question.question_text << "<div id=qfi#{index + 1}-#{hyphen.length}r class=quiz></div></br></br>"
            
          elsif question.class == DragDrop
            hyphen = question.question_text.scan(/(?<!\\)---+/)
            hyphen.length.times { |i|
                                 nHyphen = hyphen[i].count('-')
                                 @size_inputs << nHyphen
                                 attr = "id=qdd#{index + 1}-#{i + 1} class='dragdrop size-#{nHyphen}' ondrop=drop(event,'qdd#{index + 1}-#{i + 1}') ondragover=allowDrop(event)"
                                 question.question_text.sub!(/(?<!\\)---+/, "<input #{attr}></input>")
                                }
            question.question_text.gsub!(/\\-/, '-')
            question.question_text << "<br/><br/>"
            question.question_text << "<div> #{translate(:answers, '')}: "
            question.answers[0].answer_text.each_with_index do |a, i|
              @size_divs << a.to_s.length
              question.question_text << "<button class='dragdrop size-#{a.to_s.length} btn btn-default btn-sm' id=qdda#{i + 1}-#{i + 1} draggable=true ondragstart=drag(event)>#{a}</button>&nbsp&nbsp"
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
          if ((question.class == FillIn) || (question.class == DragDrop))
            @data[html_args[:id].to_sym] = {:question_text => questionText, :answers => {}, :points => question.points, 
                                            :order => question.order, :question_comment => question.question_comment}
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
    insert_button("show-answer-q-#{index}", translate(:show, 'buttons'), 'btn btn-success btn-sm') unless flag
    insert_button("q-#{index}", translate(:submit, 'buttons'), 'btn btn-primary btn-sm')
    @h.br do
    end
  end
  
  def insert_resources_head(h)
    insert_defaultCSS
    insert_html(h) if @html
    insert_css(false) if @css
    insert_mathjax(false)
  end
  
  def insert_resources_body(b)
    insert_jQuery(b, false)
    insert_xregexp(false)
    insert_js(false) if @js
    
    @h.script(:type => 'text/javascript') do |j|
      j << insert_drag_drop
    end
    
    @h.script(:type => 'text/javascript') do |j|
      j << yml_to_json
    end
    @h.script(:type => 'text/javascript') do |j|
      j << insert_defaultJS(@quiz.points)
    end
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
          code << "<link rel=stylesheet type=text/css href=#{File.expand_path(file)} />\n"
        end
      else
        @css.each do |file|
          @h.link(:rel => 'stylesheet', :type =>'text/css', :href => File.expand_path(file))
        end
      end
    else
      if (template)
        code << "<link rel=stylesheet type=text/css href=#{File.expand_path(@css)} />"
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
    if (template)
      code = %q{
        <script type=text/javascript src=http://code.jquery.com/jquery-2.1.0.min.js></script>
        <script type='text/javascript' src="http://code.jquery.com/ui/1.10.3/jquery-ui.js"></script>
        <!--[if lt IE 8]>
          <script type=text/javascript src=http://code.jquery.com/jquery-1.11.0.min.js></script>
        <![endif]-->
      }
      code
    else
      @h.script(:type => 'text/javascript', :src => "http://code.jquery.com/jquery-2.1.0.min.js") do
      end
      h << "<!--[if lt IE 8]>"
      @h.script(:type => 'text/javascript', :src => "http://code.jquery.com/jquery-1.11.0.min.js") do
      end
      h << "<![endif]-->"
    end
  end
  
  def insert_xregexp(template)
    if (template)
      code = "<script type=text/javascript src=http://cdnjs.cloudflare.com/ajax/libs/xregexp/2.0.0/xregexp-min.js></script>"
      code
    else
      @h.script(:type => 'text/javascript', :src => "http://cdnjs.cloudflare.com/ajax/libs/xregexp/2.0.0/xregexp-min.js") do
      end
    end
  end
  
  def insert_mathjax(template)
    if (template)
      code = %q{
        <script type=text/javascript src=http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML></script>
        <script type=text/javascript>
          MathJax.Hub.Config({tex2jax: {inlineMath: [['$','$'], ['\\\(','\\\)']]}});
        </script>
      }
    else
      @h.script(:type => 'text/javascript', :src => "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML") do
      end
      @h.script(:type => 'text/javascript') do |j|
        j << "MathJax.Hub.Config({tex2jax: {inlineMath: [['$','$'], ['\\\\(','\\\\)']]}});"
      end
    end
  end
  
  def insert_drag_drop
    <<-DD
      function allowDrop(ev) {
        ev.preventDefault();
      }
      
      function drag(ev) {
        ev.dataTransfer.setData("Text",ev.target.id);
      }
      
      function drop(ev, id) {
        ev.preventDefault();
        var data=ev.dataTransfer.getData("Text");
        ev.target.appendChild(document.getElementById(data));
        var val=document.getElementById(id);
        val.value=document.getElementById(data).innerText;
      }
    DD
  end
  
  def insert_js(template)
    code = ""
    if (@js.class == Array)
      if (template)
        @js.each do |file|
          code << "<script type=text/javascript src=#{File.expand_path(file)}></script>\n"
        end
      else
        @js.each do |file|
            @h.script(:type => 'text/javascript', :src => File.expand_path(file)) do
            end
        end
      end
    else
      if (template)
        code << "<script type=text/javascript src=#{File.expand_path(@js)}></script>\n"
      else
        @h.script(:type => 'text/javascript', :src => File.expand_path(@js)) do
        end
      end
    end
    code if template
  end
  
  def load_yml
    I18n.enforce_available_locales = false
    I18n.load_path = Dir['config/locales/*.yml']
  end
  
  def yml_to_json
    yml = File.read("config/locales/#{@language.to_s}.yml")
    data = YAML::load(yml)
    json = JSON.dump(data)
    <<-i18n
      i18n = #{json}
    i18n
  end
  
  def translate(word, scope)
    I18n.translate word, :scope => scope, :locale => @language
  end
  
  def insert_defaultCSS
    @h.style do |s|
      s << <<-CSS
      div.quiz, p.comment, div.explanation {display:inline;}
      strong.correct {color:#14B63F;}
      strong.incorrect {color:rgb(255,0,0);}
      strong.mark {color:rgb(255,128,0);}
      input.correct {color:#14B63F; font-weight: bold;}
      input.incorrect {color:rgb(255,0,0); font-weight: bold;}
      div.btn-footer {text-align: center;}
      div.explanation {font-style: italic;}
      CSS
    end
  end
 
  def insert_defaultJS(totalPoints)
    <<-JS
      data = #{@data.to_json};
      timestamp = #{Time.now.getutc.to_i}
      timestamp = timestamp.toString();
      language = '#{@language.to_s}';
      totalPoints = #{totalPoints};
      userPoints = 0;
      
      function findCorrectAnswer(idQuestion, questionType) {
        correctIds = [];
        for (id in data[idQuestion]['answers']) {
          if(data[idQuestion]['answers'][id.toString()]['correct'] == true)
            if (questionType == 0)
              return id.toString();
            else {
              correctIds.push(id.toString());
            } 
        }
        return correctIds;
      }
      
      function checkSelectMultiple(x, checkedIds, correctIds) {
        results = [];
        
        $.each(checkedIds, function(index, value){
          if (correctIds.indexOf(value) == -1) {
            results.push(false);
            printResults(value, 0, data[x.toString()]['answers'][value]['explanation'], 0);
          }
          else {
            results.push(true);
            printResults(value, 1, data[x.toString()]['answers'][value]['explanation'], 0);
          }
        });
        
        nCorrects = 0;
        nIncorrects = 0;
        $.each(results, function(index, value){
          if (value == true)
            nCorrects += 1;
          else
            nIncorrects += 1;
        });
        
        userPoints += calculateMark(data[x.toString()], x.toString(), null, 3, nCorrects, nIncorrects);
      }
      
      function printResults(id, type, explanation, typeQuestion) {
        if (typeQuestion == 0) {                                        // MultipleChoice and SelectMultiple
          $("br[class=" + id + "br" + "]").detach();
          if (type == 1) {
            if ((explanation == "") || (explanation == null))
              $("div[id ~= " + id + "r" + "]").html("<strong class=correct> " + i18n[language]['questions']['correct'] + "</strong></br>");
            else
              $("div[id ~= " + id + "r" + "]").html("<strong class=correct> " + i18n[language]['questions']['correct'] + " - " + explanation + "</strong></br>");
          }
          else {
            if ((explanation == "") || (explanation == null))
              $("div[id ~= " + id + "r" + "]").html("<strong class=incorrect> " + i18n[language]['questions']['incorrect'] + "</strong></br>");
            else
              $("div[id ~= " + id + "r" + "]").html("<strong class=incorrect> " + i18n[language]['questions']['incorrect'] + " - " + explanation + "</strong></br>");
          }
        }
        else {          // FillIn
          for (r in id) {
            input = $("#" + r.toString());
            if (id[r] == true) {
              input.attr('class', input.attr('class') + ' correct');
            }
            else { 
              if ((id[r] == false) || (id[r] != "n/a")) {
                input.attr('class', input.attr('class') + ' incorrect');
              }
            }
            
            if ((id[r] != true) && (id[r] != false) && (id[r] != "n/a")) {
              if (explanation[id[r].toString()] != null)
                $("div[id ~= " + r.toString() + "r" + "]").html(" <div class=explanation>" + explanation[id[r].toString()] + "</div>");
            }
            else {
              if (explanation[r] != null)
                $("div[id ~= " + r + "r" + "]").html(" <div class=explanation>" + explanation[r] + "</div>");
            }
          }
        }
      }
      
      function calculateMark(question, id, result, typeQuestion, numberCorrects, numberIncorrects) {
        stringPoints = i18n[language]['questions']['points'];
        if (typeQuestion == 2) {
          if (result) {
            $("#" + id).append("<strong class=mark> " + question['points'].toFixed(2) + "/" + question['points'].toFixed(2) + " " + stringPoints + "</strong></br></br>");
            
            return parseFloat(question['points']);
          }
          else {
            $("#" + id).append("<strong class=mark> 0.00/" + question['points'].toFixed(2) + " " + stringPoints + "</strong></br></br>");
            
            return parseFloat(0);
          }
        }
        else if (typeQuestion == 1) {
          size = 0;
          for (y in question['answers'])
            if (question['answers'][y]['correct'] == true)
              size += 1;
              
          pointsUser = ((question['points'] / size) * numberCorrects).toFixed(2);
          $("#" + id).append("<strong class=mark> " + pointsUser + "/" + question['points'].toFixed(2) + " " + stringPoints + "</strong></br></br>");
         
          return parseFloat(pointsUser);
        }
        else {
          totalCorrects = 0;
          for (y in question['answers']) {
            if (question['answers'][y]['correct'] == true)
              totalCorrects += 1;
          }
          
          correctAnswerPoints = question['points'] / totalCorrects;
          penalty = correctAnswerPoints * numberIncorrects;
          mark = (correctAnswerPoints * numberCorrects) - penalty;
          
          if (mark < 0)
            mark = 0;
            
          $("#" + id).append("<strong class=mark> " + mark.toFixed(2) + "/" + question['points'].toFixed(2) + " " + stringPoints + "</strong></br></br>");        
          
          return parseFloat(mark);
        }
      }
      
      function checkFillin(correctAnswers, userAnswers, distractorAnswers, typeCorrection) {
        correction = {};
        checkedAnswers = {};
        
        if (typeCorrection == 0) {          // Order doesn't matter
          for (u in userAnswers) {
            if (userAnswers[u] != undefined) {    // No empty field
              matchedCorrect = false;
              for (y in correctAnswers) {
                if (checkAnswers[u] == undefined) {
                  if ((typeof(correctAnswers[y]) == "string") || (typeof(correctAnswers[y]) == "number")) {    // Answer is a String or a Number
                    if (userAnswers[u] == correctAnswers[y]) {
                      correction[u] = true;
                      checkedAnswers[u] = userAnswers[u];
                      matchedCorrect = true;
                      break;
                    }
                  }
                  else {  // Answer is a Regexp
                    if (XRegExp.exec(userAnswers[u], correctAnswers[y])) {
                      correction[u] = true;
                      checkedAnswers[u] = userAnswers[u];
                      matchedCorrect = true;
                      break;
                    }
                  }
                }
              }
              if (!matchedCorrect)
                correction[u] = false;
            }
            else
              correction[u] = "n/a";
          }
        }
        else {                            // Order matters
          for (u in userAnswers) {
            if (userAnswers[u] != undefined) {
              if ((typeof(correctAnswers[u]) == "string") || (typeof(correctAnswers[u]) == "number")) {
                if (userAnswers[u] == correctAnswers[u])
                  correction[u] = true;
                else
                  correction[u] = false;
              }
              else {
                if (XRegExp.exec(userAnswers[u], correctAnswers[u]))
                  correction[u] = true;
                else
                  correction[u] = false;
              }
            }
            else
              correction[u] = "n/a";
          }
        }
        
        if (Object.keys(userAnswers).length == 1) {
          for (u in userAnswers) {
            if (correction[u] == false) {
              for (y in distractorAnswers) {
                if ((typeof(distractorAnswers[y]) == "string") || (typeof(distractorAnswers[y]) == "number")) {
                  if (userAnswers[u] == distractorAnswers[y])
                    correction[u] = y.toString();
                }
                else {
                  if (XRegExp.exec(userAnswers[u], distractorAnswers[y]))
                    correction[u] = y.toString();
                }
              }
            }
          }
        }
        return correction;
      }
      
      function checkAnswer(x) {
        
        if ($("#" + x.toString() + " strong").length == 0) {
          correct = false;
          answers = $("#" + x.toString() + " input");
          
          if ((answers.attr('class').match("fillin")) || (answers.attr('class').match("dragdrop"))) {
            correctAnswers = {};
            distractorAnswers = {};
            explanation = {};
            stringAnswer = false;
            flag_js = false;
            
            for (ans in data[x.toString()]['answers']) {
              if (data[x.toString()]['answers'][ans]['correct'] == true) {
                if (data[x.toString()]['answers'][ans]['type'] == "Regexp") {
                  string = data[x.toString()]['answers'][ans]['answer_text'].split('/');
                  regexp = string[1];
                  options = string[2];
                  correctAnswers[ans.toString()] = XRegExp(regexp, options);
                }
                else if (data[x.toString()]['answers'][ans]['type'] == "JS") {
                  flag_js = true;
                }
                else { // String or Number
                  correctAnswers[ans.toString()] = data[x.toString()]['answers'][ans]['answer_text'];
                  stringAnswer = true;
                }
              }
              else {
                if (data[x.toString()]['answers'][ans]['type'] == "Regexp") {
                  string = data[x.toString()]['answers'][ans]['answer_text'].split('/');
                  regexp = string[1];
                  options = string[2];
                  distractorAnswers[ans.toString()] = XRegExp(regexp, options);
                }
                else if (data[x.toString()]['answers'][ans]['type'] == "JS") {
                  //
                }
                else {// String or Number
                  distractorAnswers[ans.toString()] = data[x.toString()]['answers'][ans]['answer_text'];
                  stringAnswer = true;
                }
              }
              explanation[ans] = data[x.toString()]['answers'][ans]['explanation'];
            }
            
            userAnswers = {};
            for (i = 0; i < answers.length; i++) {
              if (answers[i].value == '')
                userAnswers[answers[i].id.toString()] = undefined;
              else
                if (stringAnswer)
                  userAnswers[answers[i].id.toString()] = answers[i].value.toLowerCase();
                else
                  userAnswers[answers[i].id.toString()] = answers[i].value;
            }
            
            if (flag_js == false) {
              if (data[x.toString()]['order'] == false)
                results = checkFillin(correctAnswers, userAnswers, distractorAnswers, 0);
              else
                results = checkFillin(correctAnswers, userAnswers, distractorAnswers, 1);
              
              allEmpty = true;
              nCorrects = 0;
              
              for (r in results) {
                if (results[r] == true)
                  nCorrects += 1;
                if (results[r] != "n/a")
                  allEmpty = false;
              }
              
              if (!allEmpty) {
                printResults(results, null, explanation, 1);
                userPoints += calculateMark(data[x.toString()], x.toString(), null, 1, nCorrects, null);
              }
            }
            else {
              nQuestion = parseInt(x.toString().split('-')[1]) + 1;
              id_answer_js = 'qfi' + nQuestion.toString() + '-1';
              result_function = eval(data[x.toString()]['answers'][id_answer_js]['answer_text']);
              
              values = [];
              ids = {};
              $.each(userAnswers, function(k,v) {
                ids[k] = false;
                values.push(eval(v));
              });
              
              result = result_function.apply(this, values);     // Execution of the function
              
              if (result) {
                $.each(ids, function(k,v) {
                  ids[k] = true;
                });
              }
              
              printResults(ids, null, explanation, 1);
              userPoints += calculateMark(data[x.toString()], x.toString(), result, 2, null, null);
            }
          }
          
          else if (answers.attr('class') == "select") {
            idCorrectAnswer = findCorrectAnswer(x.toString(), 0);
            
            if ($("#" + x.toString() + " :checked").size() != 0) {
              if ($("#" + x.toString() + " :checked").attr('id') == idCorrectAnswer) {
                printResults($("#" + x.toString() + " :checked").attr('id'), 1, "", 0);
                correct = true;
              }
              else {
                id = $("#" + x.toString() + " :checked").attr('id');
                printResults(id, 0, data[x.toString()]['answers'][id]['explanation'], 0);
              }
              userPoints += calculateMark(data[x.toString()], x.toString(), correct, 2, null, null);
            }
          }
          
          else {
            if ($("#" + x.toString() + " :checked").size() != 0) {
              answers = $("#" + x.toString() + " :checked");
              checkedIds = [];
              
              $.each(answers, function(index, value){
                checkedIds.push(value['id']);
              });
              
              correctIds = [];
              correctIds = findCorrectAnswer(x.toString(), 1);
              checkSelectMultiple(x, checkedIds, correctIds);
            }
          }
        }
      }
      
      function checkAnswers() {
        for (x in data) {
          checkAnswer(x);
        }
      }
      
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
          localStorage.setItem(timestamp, JSON.stringify(tmp));
        }
        else {
          alert(i18n[language]['alerts']['noStorage']);
        }
      }
      
      function loadAnswers() {
        if ((localStorage.length != 0) && (localStorage[timestamp] !== undefined)) {
          tmp = JSON.parse(localStorage[timestamp]);
          for (x in tmp) {
            if ((x.match(/qfi/)) || (x.match(/qdd/)))
              $("#" + x.toString()).val(tmp[x.toString()]);
            else
              $("#" + x.toString()).attr('checked', 'checked');
          }
        }
      }
      
      function deleteAnswers(all) {
        if (all) {
          localStorage.clear();
          alert(i18n[language]['alerts']['storage']);
        }
        else {
          localStorage.removeItem(timestamp);
          alert(i18n[language]['alerts']['answers']);
        }
      }
      
      function showTotalScore() {
        $("#score").html(i18n[language]['questions']['score'] + ": " + userPoints.toFixed(2) + "/" + totalPoints.toFixed(2) + " " + i18n[language]['questions']['points'])
      }
      
      function reload() {
        window.location.reload();
      }
      
      function changeButton(button, numQuestion) {
        if (button.attr('class').match('success')) {
          button.attr('class', button.attr('class').replace('success', 'danger'));
          button.html(i18n[language]['buttons']['hide']);
          showOrHideAnswer(numQuestion, 1);
        }
        else if (button.attr('class').match('danger')){
          button.attr('class', button.attr('class').replace('danger', 'success'));
          button.html(i18n[language]['buttons']['show']);
          showOrHideAnswer(numQuestion, 0);
        }
      }
      
      function showOrHideAnswer(numQuestion, flag) {
        answers = data['question-' + numQuestion.toString()]['answers'];
        typeQuestion = Object.keys(answers)[0].split('-')[0].slice(0, 3);
        numQuestion = (++numQuestion).toString();
        
        if (typeQuestion.match(/^qfi$/)) {
          inputs = $("input[id^=qfi" + numQuestion + "-");
          
          $.each(inputs, function(index, value) {
            if (flag == 1)
              $("input[id=" + value.id).val(answers[value.id]['answer_text']);
            else
              $("input[id=" + value.id).val('');
          });
        }
        else if (typeQuestion.match(/^qmc$/)){
          inputs = $("input[id^=qmc" + numQuestion + "-");
          correct = '';
          
          $.each(answers, function(key, value) {
            if (value['correct'] == true)
              correct = key;
          })
          
          if (flag == 1)
            $("input[id=" + correct).prop('checked', true);
          else
            $("input[id=" + correct).prop('checked', false);
        }
        else {
          inputs = $("input[id^=qsm" + numQuestion + "-");
          corrects = [];
          $.each(answers, function(key, value) {
            if (answers[key]['correct'] == true)
              corrects.push(key);
          }); 
          
          $.each(corrects, function(index, value) {
            if (flag == 1)
              $("input[id=" + value).prop('checked', true);
            else
              $("input[id=" + value).prop('checked', false);
          });
        }
      }
      
      $("#submit").click(function() {
        checkAnswers();
        filledAllQuiz = true;
        
        for (x in data) {
          if ($("#" + x.toString() + " strong").length == 0)
            filledAllQuiz = false; 
        }
        if (filledAllQuiz)
          $("#submit").detach();
        
        storeAnswers();
        showTotalScore();
      });

      $("#reset").click(function() {
        reload();
      });
      
      $("#deleteAnswers").click(function() {
        deleteAnswers(false);
        reload();
      });
      
      $("#deleteStorage").click(function() {
        deleteAnswers(true);
        reload();
      });
      
      $("button[id^=show-answer-q-").click(function() {
        numQuestion = parseInt($(this).attr('id').split('-')[3]);
        changeButton($(this), numQuestion);
      });
      
      $("button[id^=q-").click(function() {
        nQuestion = $(this).attr('id').split('-')[1];
        checkAnswer('question-' + nQuestion);
        storeAnswers();
        showTotalScore();
      });
      
      $(document).ready(function() {
        loadAnswers();
      });
      JS
  end
end
