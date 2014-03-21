class HtmlFormRenderer
  require 'builder'
  require 'erb'
  require 'json'
  
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
  end

  def render_quiz
    if @template
      render_with_template do
        render_questions
        @output
      end
    else
      @h.html do
        @h.head do |h|
          @h.title @quiz.title
          insert_resources(h)
        end
        @h.body do
          render_questions
          insert_defaultJS
        end
      end
    end
    self
  end

  def render_with_template
    # local variables that should be in scope in the template 
    quiz = @quiz
    title = "Quiz" unless @title
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
      insert_button('Submit')
      insert_button('Reset')
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
          @h.div(:id => "qmc#{index + 1}-#{id_answer}r") do
          end
          id_answer += 1
        end
        @h.br
      end
    end
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
          @h.div(:id => "qsm#{index + 1}-#{id_answer}r") do
          end
          id_answer += 1
        end
        @h.br
      end
    end
    self
  end
  
  def render_fill_in(q, idx)
    render_question_text(q, idx) do
      # Store answers for question-idx
      answer = q.answers[0]
      answers = (answer.answer_text.kind_of?(Array) ? answer.answer_text : [answer.answer_text])
      id_answer = 1
      
      answers.each do |a|
        if (a.class == Regexp)
          ans = a.source
          type = 'Regexp'
          [0, -1].each {|index| ans.insert(index, '/')}
        elsif (a.class == String)
          ans = a.downcase
          type = 'String'
        else
          ans = a
          type = 'Fixnum'
        end
        
        @data[:"question-#{idx}"][:answers]["qfi#{idx + 1}-#{id_answer}".to_sym] = {:answer_text => ans, :correct => answer.correct, 
                                                                                    :explanation => answer.explanation, :type => type}
        id_answer += 1
      end
    end
  end

  def render_question_text(question,index)
    html_args = {
      :id => "question-#{index}",
      :class => ['question', question.class.to_s.downcase, (question.multiple ? 'multiple' : '')]
        .join(' ')
    }
    @h.li html_args  do
      @h.div :class => 'text' do
        questionText = question.question_text.clone
        qtext = "[#{question.points} point#{'s' if question.points>1}] " <<
          ('Select ALL that apply: ' if question.multiple).to_s <<
          if question.class == FillIn
            question.question_text.chop! if question.question_text[-1] == '.'
            nBoxes = question.question_text.split('---').length
            nBoxes.times { |i| question.question_text.sub!(/\---/, "<input type=text id=qfi#{index + 1}-#{i + 1} class=fillin></input>") }
            question.question_text << "<div id=qfi#{index + 1}-#{nBoxes}r></div></br></br>"
          else 
            question.question_text
          end
          
          # Hash with questions and all posibles answers
          if (question.class == FillIn)
            @data[html_args[:id].to_sym] = {:question_text => questionText, :answers => {}, :points => question.points, :order => question.order}
          else
            @data[html_args[:id].to_sym] = {:question_text => questionText, :answers => {}, :points => question.points}
          end
          
          if (question.raw?)
            @h.p do |p|
              p << qtext
            end
          else
            qtext.each_line do |p|
              @h.p do |par|
                par << p # preserves HTML markup
              end 
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
  
  def insert_button(name)
    @h.button(:type => 'button', :id => name.downcase) do |b|
      b << name
    end
  end
  
  def insert_resources(h)
    insert_defaultCSS
    insert_html(h) if @html
    insert_css if @css
    insert_jQuery(h)
    insert_js if @js
  end
  
  def insert_html(h)
    if (@html.class == Array)
      @html.each do |file|
        h << File.read(file)
      end
    else
      h << File.read(@html)
    end
  end
  
  def insert_css
    if (@css.class == Array)
      @css.each do |file|
        @h.link(:rel => 'stylesheet', :type =>'text/css', :href => file) 
      end
    else
      @h.link(:rel => 'stylesheet', :type =>'text/css', :href => @css)
    end
  end
  
  def insert_jQuery(h)
    @h.script(:type => 'text/javascript', :src => "http://code.jquery.com/jquery-2.1.0.min.js") do
    end
    h << "<!--[if lt IE 8]>"
    @h.script(:type => 'text/javascript', :src => "http://code.jquery.com/jquery-1.11.0.min.js") do
    end
    h << "<![endif]-->"
  end
  
  def insert_js
    if (@js.class == Array)
      @js.each do |file|
        @h.script(:type => 'text/javascript', :src => file) do
        end
      end
    else
      @h.script(:type => 'text/javascript', :src => @js) do
      end
    end
  end
  
  def insert_defaultCSS
    @h.style do |s|
      s << <<-CSS
      div, p {display:inline;}
      strong.correct {color:rgb(0,255,0);}
      strong.incorrect {color:rgb(255,0,0);}
      strong.mark {color:rgb(255,128,0);}
      input.correct {color:rgb(0,255,0); font-weight: bold;}
      input.incorrect {color:rgb(255,0,0); font-weight: bold;}
      CSS
    end
  end
  
  def insert_defaultJS
    @h.script(:type => 'text/javascript') do |j|
      j << <<-JS
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
              $("div[id ~= " + id + "r" + "]").html("<strong class=correct> Correct</strong></br>");
            else
              $("div[id ~= " + id + "r" + "]").html("<strong class=correct> Correct - " + explanation + "</strong></br>");
          }
          else {
            if ((explanation == "") || (explanation == null))
              $("div[id ~= " + id + "r" + "]").html("<strong class=incorrect> Incorrect</strong></br>");
            else
              $("div[id ~= " + id + "r" + "]").html("<strong class=incorrect> Incorrect - " + explanation + "</strong></br>");
          }
        }
        else {          // FillIn
          for (r in id) {
            input = $("#" + r.toString());
            if (id[r] == true)
              input.attr('class', 'fillin correct');
            else { 
              if (id[r] == false)
                input.attr('class', 'fillin incorrect');
            }
            if (explanation != null)
              $("div[id ~= " + r + "r" + "]").html("Explanation: " + explanation);
          }
        }
      }
      
      function calculateMark(question, id, result, typeQuestion, numberCorrects, numberIncorrects) {
        if (typeQuestion == 2) {
          if (result)
            $("#" + id).append("<strong class=mark> " + question['points'].toFixed(2) + "/" + question['points'].toFixed(2) + " points</strong></br></br>");
          else
            $("#" + id).append("<strong class=mark> 0.00/" + question['points'].toFixed(2) + " points</strong></br></br>");
        }
        else if (typeQuestion == 1) {
          size = 0;
          for (y in question['answers']) {
            size += 1;
          }
          
          $("#" + id).append("<strong class=mark> " + ((question['points'] / size) * numberCorrects).toFixed(2) + "/" + question['points'].toFixed(2) + " points</strong></br></br>");
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
            
          $("#" + id).append("<strong class=mark> " + mark.toFixed(2) + "/" + question['points'].toFixed(2) + " points</strong></br></br>");        
        }
      }
      
      function checkFillin(correctAnswers, userAnswers, typeCorrection) {
        correction = {};
        checkedAnswers = {};

        if (typeCorrection == 0) {          // Order doesn't matter
          for (u in userAnswers) {
            if (userAnswers[u] != undefined) {    // No empty field
              matched = false;
              for (y in correctAnswers) {
                if (checkAnswers[u] == undefined) {
                  if ((typeof(correctAnswers[y]) == "string") || (typeof(correctAnswers[y] == "number"))) {    // Answer is a String or a Number
                    if (userAnswers[u] == correctAnswers[y]) {
                      correction[u] = true;
                      checkedAnswers[u] = userAnswers[u];
                      matched = true;
                      break;
                    }
                  }
                  else {  // Answer is a Regexp
                    if (userAnswers[u].match(correctAnswers[y])) {
                      correction[u] = true;
                      checkedAnswers[u] = userAnswers[u];
                      matched = true;
                      break;
                    }
                  }
                }
              }
              if (!matched)
                correction[u] = false;
            }
            else
              correction[u] = "n/a";
          }
        }
        else {                            // Order matters
          for (u in userAnswers) {
            if (userAnswers[u] != undefined) {
              if (typeof(correctAnswers[u] == "string")) {
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
        return correction;
      }
      
      function checkAnswers() {
        
        for (x in data) {
          if ($("#" + x.toString() + " strong").length == 0) {
            correct = false;
            answers = $("#" + x.toString() + " input");
            
            if (answers.attr('class') == "fillin") {
              correctAnswers = {};
              explanation = "";
              stringAnswer = false;
              
              for (ans in data[x.toString()]['answers']) {
                if (data[x.toString()]['answers'][ans]['type'] == "Regexp")
                  correctAnswers[ans.toString()] = RegExp(data[x.toString()]['answers'][ans]['answer_text'].split('/').join(''));
                else { // String
                  correctAnswers[ans.toString()] = data[x.toString()]['answers'][ans]['answer_text'];
                  stringAnswer = true;
                }
                explanation = data[x.toString()]['answers'][ans]['explanation'];
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
                results = checkFillin(correctAnswers, userAnswers, 0);
              else
                results = checkFillin(correctAnswers, userAnswers, 1);
                
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
end
