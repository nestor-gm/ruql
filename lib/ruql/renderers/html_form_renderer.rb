class HtmlFormRenderer
  require 'builder'
  require 'erb'
  require 'json'
  require 'sass'
  
  attr_reader :output

  def initialize(quiz,options={})
    @css = options.delete('c') || options.delete('css')
    @js = options.delete('j') || options.delete('js')
    @html = options.delete('h') || options.delete('html')
    @show_solutions = options.delete('s') || options.delete('solutions')
    @template = options.delete('t') ||
      options.delete('template')
    @output = ''
    @quiz = quiz
    @h = Builder::XmlMarkup.new(:target => @output, :indent => 2)
    @data = {}
    @size_inputs = []
  end

  def render_quiz
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
    title = "Quiz" unless @title
    @css_custom = insert_css(true) if @css
    @js_custom = insert_js(true) if @js
    @jQuery = insert_jQuery('', true)
    @mathjax = insert_mathjax(true)
    @xregexp = insert_xregexp(true)
    @codehelper = get_ip_js(true)
    @validation_js = insert_defaultJS
    @i18n = insert_i18n
    
    render_questions
    @sass = insert_sass
    
    # the ERB template includes 'yield' where questions should go:
    output = ERB.new(IO.read(File.expand_path @template)).result(binding)
    @output = output
  end
    
  def render_questions
    render_random_seed
    @h.form(:id => 'form') do
      @h.ol :class => 'questions' do
        @quiz.questions.each_with_index do |q,i|
          case q
          when SelectMultiple then render_select_multiple(q,i)
          when MultipleChoice, TrueFalse then render_multiple_choice(q,i)
          when FillIn then render_fill_in(q, i)
          else
            raise "Unknown question type: #{q}"
          end
        end
      end
      @h.div :class => 'btn-footer' do
        insert_button('Submit', 'btn btn-primary')
        insert_button('Reset', 'btn btn-warning')
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
    self
  end
  
  def type_answer_fill_in(answer, item, idx, id_answer)
    if (item.class == Regexp)
      ans = item.source
      type = 'Regexp'
      [0, -1].each {|index| ans.insert(index, '/')}
      opts = item.options
      case opts
        when 0, 16
        when 1, 3, 17
          ans << 'i'
        when 4, 6, 20
          ans << 'm'
        when 5, 7, 21
          ans << 'mi'
      end
      if ((opts != 0) && (opts != 1) && (opts != 4) && (opts != 5) && (opts != 16) && (opts != 17) && (opts != 20) && (opts != 21))
        $stderr.puts "\n*** WARNING *** These RegExps only support i and m options. Other options will be ignored.\n\n"
      end
    elsif (item.class == String)
      ans = item.downcase
      type = 'String'
    else
      ans = item
      type = 'Fixnum'
    end
    @data[:"question-#{idx}"][:answers]["qfi#{idx + 1}-#{id_answer}".to_sym] = {:answer_text => ans, :correct => answer.correct, 
                                                                                :explanation => answer.explanation, :type => type}
  end
  
  def render_fill_in(q, idx)
    render_question_text(q, idx) do
      question_comment(q)
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
        type_answer_fill_in(answer, a, idx, id_answer)
        id_answer += 1
      end
      
      id_distractor = 2
      if (!distractor.empty?)
        distractors.each_index do |i|
          type_answer_fill_in(distractors[i], distractors[i].answer_text, idx, id_distractor)
          id_distractor += 1
        end
      end
    end
  end
  
  def raw_html(text)
    text.gsub!('#<', '&lt;')
    text.gsub!('#>', '&gt;')
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
            question.question_text.chop! if question.question_text[-1] == '.'
            raw_html(question.question_text)
            
            hyphen = []
            tmp = question.question_text.split(/[^-]/)
            tmp.each { |w| hyphen << w if (w =~ /---+/)}

            $stderr.puts hyphen
            hyphen.length.times { |i|
                                 nHyphen = hyphen[i].count('-')
                                 @size_inputs << nHyphen
                                 question.question_text.sub!(/\---+/, "<input type=text id=qfi#{index + 1}-#{i + 1} class='fillin size-#{nHyphen}'></input>")
                                }
            
            question.question_text << "<div id=qfi#{index + 1}-#{hyphen.length}r class=quiz></div></br></br>"
          else 
            if (question.raw?)
              question.question_text
            else
              question.question_text << "<br></br>"
            end
          end
          
          # Hash with questions and all posibles answers
          if (question.class == FillIn)
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
  
  def insert_button(name, type)
    @h.button(:type => 'button', :id => name.downcase, :class => type) do |b|
      b << name
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
    get_ip_js(false)
    insert_xregexp(false)
    insert_js(false) if @js
    
    @h.script(:type => 'text/javascript') do |j|
      j << insert_i18n
    end
    @h.script(:type => 'text/javascript') do |j|
      j << insert_defaultJS
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
  
  def insert_sass
    sass = ""
    @size_inputs.uniq!.sort!.each { |sz| sass << "input.size-#{sz.to_s} { width: #{sz}em}"}
    engine = Sass::Engine.new(sass, :syntax => :scss)
    engine.options[:style] = :compact
    engine.render
  end
  
  def insert_jQuery(h, template)
    if (template)
      code = %q{
        <script type=text/javascript src=http://code.jquery.com/jquery-2.1.0.min.js></script>
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
  
  def get_ip_js(template)
    if (template)
      code = "<script type=text/javascript src=http://www.codehelper.io/api/ips/?js></script>"
      code
    else
      @h.script(:type => 'text/javascript', :src => "http://www.codehelper.io/api/ips/?js") do
      end
    end
  end
  
  def insert_i18n
    <<-i18n
      i18n = {};
      i18n['ES'] = {}
      i18n['ES']['correct'] = "Correcto";
      i18n['ES']['incorrect'] = "Incorrecto";
      i18n['ES']['points'] = "puntos";
      i18n['EN'] = {}
      i18n['EN']['correct'] = "Correct";
      i18n['EN']['incorrect'] = "Incorrect";
      i18n['EN']['points'] = "points";
    i18n
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
 
  def insert_defaultJS
    <<-JS
      data = #{@data.to_json};

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
        
        calculateMark(data[x.toString()], x.toString(), null, 3, nCorrects, nIncorrects);
      }
      
      function printResults(id, type, explanation, typeQuestion) {
        if (typeQuestion == 0) {                                        // MultipleChoice and SelectMultiple
          $("br[class=" + id + "br" + "]").detach();
          if (type == 1) {
            if ((explanation == "") || (explanation == null))
              $("div[id ~= " + id + "r" + "]").html("<strong class=correct> " + i18n[language]['correct'] + "</strong></br>");
            else
              $("div[id ~= " + id + "r" + "]").html("<strong class=correct> " + i18n[language]['correct'] + " - " + explanation + "</strong></br>");
          }
          else {
            if ((explanation == "") || (explanation == null))
              $("div[id ~= " + id + "r" + "]").html("<strong class=incorrect> " + i18n[language]['incorrect'] + "</strong></br>");
            else
              $("div[id ~= " + id + "r" + "]").html("<strong class=incorrect> " + i18n[language]['incorrect'] + " - " + explanation + "</strong></br>");
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
        if (typeQuestion == 2) {
          if (result)
            $("#" + id).append("<strong class=mark> " + question['points'].toFixed(2) + "/" + question['points'].toFixed(2) + " " + i18n[language]['points'] + "</strong></br></br>");
          else
            $("#" + id).append("<strong class=mark> 0.00/" + question['points'].toFixed(2) + " " + i18n[language]['points'] + "</strong></br></br>");
        }
        else if (typeQuestion == 1) {
          size = 0;
          for (y in question['answers'])
            if (question['answers'][y]['correct'] == true)
              size += 1;
              
          pointsUser = ((question['points'] / size) * numberCorrects).toFixed(2);
          $("#" + id).append("<strong class=mark> " + pointsUser + "/" + question['points'].toFixed(2) + " " + i18n[language]['points'] + "</strong></br></br>");
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
            
          $("#" + id).append("<strong class=mark> " + mark.toFixed(2) + "/" + question['points'].toFixed(2) + " " + i18n[language]['points'] + "</strong></br></br>");        
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
                    if (userAnswers[u].match(correctAnswers[y])) {
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
                if (userAnswers[u].match(correctAnswers[u]))
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
                  if (userAnswers[u].match(distractorAnswers[y]))
                    correction[u] = y.toString();
                }
              }
            }
          }
        }
        return correction;
      }
      
      function checkAnswers() {
        
        for (x in data) {
          if ($("#" + x.toString() + " strong").length == 0) {
            correct = false;
            answers = $("#" + x.toString() + " input");
            
            if (answers.attr('class').match("fillin")) {
              correctAnswers = {};
              distractorAnswers = {};
              explanation = {};
              stringAnswer = false;
              
              for (ans in data[x.toString()]['answers']) {
                if (data[x.toString()]['answers'][ans]['correct'] == true) {
                  if (data[x.toString()]['answers'][ans]['type'] == "Regexp") {
                    string = data[x.toString()]['answers'][ans]['answer_text'].split('/');
                    regexp = string[1];
                    options = string[2];
                    correctAnswers[ans.toString()] = RegExp(regexp, options);
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
                    distractorAnswers[ans.toString()] = RegExp(regexp, options);
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
                calculateMark(data[x.toString()], x.toString(), null, 1, nCorrects, null);
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
                calculateMark(data[x.toString()], x.toString(), correct, 2, null, null);
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
      }

      if (typeof(codehelper_ip) == "undefined")
        language = "EN";
      else
        language = codehelper_ip.Country;
      
      $("#submit").click(function() {
        checkAnswers();
        filledAllQuiz = true;
        
        for (x in data) {
          if ($("#" + x.toString() + " strong").length == 0)
            filledAllQuiz = false; 
        }
        if (filledAllQuiz)
          $("#submit").detach();
      });

      $("#reset").click(function() {
        window.location.reload();
      });
      JS
  end
end
