class HtmlFormRenderer
  require 'builder'
  require 'erb'
  require 'json'
  
  attr_reader :output

  def initialize(quiz,options={})
    @css = options.delete('c') || options.delete('css')
    @js = options.delete('j') || options.delete('js')
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
          @h.link(:rel => 'stylesheet', :type =>'text/css', :href => @css) if @css
          @h.style do |s|
            s << "div, p {display:inline;}"
            s << "strong.correct {color:rgb(0,255,0);}"
            s << "strong.incorrect {color:rgb(255,0,0);}"
            s << "strong.mark {color:rgb(255,128,0);}"
          end
          @h.script(:type => 'text/javascript', :src => "http://code.jquery.com/jquery-2.1.0.min.js") do
          end
          h << "<!-[if lt IE 8]>"
          @h.script(:type => 'text/javascript', :src => "http://code.jquery.com/jquery-1.11.0.min.js") do
          end
          h << "<![endif]->"
          @h.script(:type => 'text/javascript', :src => @js) do
          end if @js
        end
        @h.body do
          render_questions
          @h.script(:type => 'text/javascript') do |j|
            j <<"#{<<JS}"
      data = #{@data.to_json};
      
      function checkFIQEmpty(textBox) {
        if (textBox == "")
          return true;
        else
          return false;
      }
      
      function checkMCQEmpty(inputs) {
        if (inputs.is(':checked'))
          return false;
        else
          return true;
      }
      
      function checkEmpty() {
        empty = []
        
        for (question in data) {
          q = $("#" + question.toString() + " input");
          if (q.length == 1)
            empty.push(checkFIQEmpty(q.val()));
          else
            empty.push(checkMCQEmpty(q));
        }
        
        if (($.inArray(true, empty)) !== -1)
          return true;
        else
          return false; 
      }
      
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
            printResults(value, 0, data[x.toString()]['answers'][value]['explanation'], "");
          }
          else {
            results.push(true);
            printResults(value, 1, "");
          }
        });
        
        nCorrects = 0;
        $.each(results, function(index, value){
          if (value == true)
            nCorrects += 1;
        });
        
        calculateMark(data[x.toString()], x.toString(), null, 3, nCorrects);
      }
      
      function printResults(id, type, explanation) {
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
      
      function calculateMark(question, id, result, typeQuestion, numberCorrects) {
        if (typeQuestion != 3) {
          if (result)
            $("#" + id).append("<strong class=mark> " + question['points'] + "/" + question['points'] + " points</strong></br></br>");
          else
            $("#" + id).append("<strong class=mark> 0/" + question['points'] + " points</strong></br></br>");
        }
        else {
          size = 0;
          for (y in question) {
            size += 1;
          }
          
          $("#" + id).append("<strong class=mark> " + ((question['points'] / size) * numberCorrects).toFixed(2) + "/" + question['points'] + " points</strong></br></br>");
        }
      }
      
      function checkAnswers() {
        
        for (x in data) {
          correct = false;
          answers = $("#" + x.toString() + " input");
          
          if (answers.attr('class') == "fillin") {
            if ($("#" + answers.attr('id')).val().toLowerCase() == data[x.toString()]['answers'][answers.attr('id')]['answer_text']) {
              printResults(answers.attr('id'), 1, "");
              correct = true;
            }
            else
              printResults(answers.attr('id'), 0, "");
            
            calculateMark(data[x.toString()], x.toString(), correct, 1, null);
          }
          
          else if (answers.attr('class') == "select") {
            idCorrectAnswer = findCorrectAnswer(x.toString(), 0);
            
            if ($("#" + x.toString() + " :checked").attr('id') == idCorrectAnswer) {
              printResults($("#" + x.toString() + " :checked").attr('id'), 1, "");
              correct = true;
            }
            else {
              id = $("#" + x.toString() + " :checked").attr('id');
              printResults(id, 0, data[x.toString()]['answers'][id]['explanation']);
            }
            
            calculateMark(data[x.toString()], x.toString(), correct, 2, null);
          }
          
          else {
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
      
      function checkForm() {
        if (!checkEmpty()) {
          checkAnswers();
        }
        else {
          alert('ERROR. Some fields are empty');
        }
      }
      
      $("#btn").click(function() {
        checkForm();
      });
      
      $("#reset").click(function() {
        window.location.reload();
      });
JS
          end
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
      @h.button(:type => 'button', :id => 'btn') do |b|
        b << "Submit"
      end
      @h.button(:type => 'button', :id => 'reset') do |b|
        b << "Retry"
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
                   
          if @show_solutions
            render_answer_for_solutions(answer, q.raw?)
          else
            @h.input(:type => 'radio', :id => "qmc#{index + 1}-#{id_answer}", :name => "qmc#{index + 1}", :class => 'select') { |p| 
              p << answer.answer_text
              p << "<br class=qmc#{index + 1}-#{id_answer}br>"
            }
            @h.div(:id => "qmc#{index + 1}-#{id_answer}r") do
            end
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
          
          if @show_solutions
            render_answer_for_solutions(answer, q.raw?)
          else
            @h.input(:type => 'checkbox', :id => "qsm#{index + 1}-#{id_answer}", :class => 'check') { |p| 
              p << answer.answer_text
              p << "<br class=qsm#{index + 1}-#{id_answer}br>"
            }
            @h.div(:id => "qsm#{index + 1}-#{id_answer}r") do
            end
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
      @data[:"question-#{idx}"][:answers]["qfi#{idx + 1}".to_sym] = {:answer_text => q.answers[0].answer_text, :correct => q.answers[0].correct, 
                                                                     :explanation => q.answers[0].explanation}
                  
      if @show_solutions
        answer = q.answers[0]
        if answer.has_explanation?
          if q.raw? then @h.p(:class => 'explanation') { |p| p << answer.explanation }
          else @h.p(answer.explanation, :class => 'explanation') end
        end
        answers = (answer.answer_text.kind_of?(Array) ? answer.answer_text : [answer.answer_text])
        @h.ol :class => 'answers' do
          answers.each do |answer|
            if answer.kind_of?(Regexp)
              answer = answer.inspect
              if !q.case_sensitive
                answer += 'i'
              end
            end
            @h.li do
              if q.raw? then @h.p { |p| p << answer } else @h.p answer end
            end
          end
        end
      end
    end
  end

  def render_answer_for_solutions(answer,raw)
    args = {:class => (answer.correct? ? 'correct' : 'incorrect')}
    @h.li(args) do
      if raw then @h.p { |p| p << answer.answer_text } else @h.p answer.answer_text  end
      if answer.has_explanation?
        if raw then @h.p(:class => 'explanation') { |p| p << answer.explanation }
        else @h.p(answer.explanation, :class => 'explanation') end
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
        qtext = "[#{question.points} point#{'s' if question.points>1}] " <<
          ('Select ALL that apply: ' if question.multiple).to_s <<
          if question.class == FillIn then question.question_text.gsub!(/\-+/, '')
          else 
            question.question_text
          end
          
          # Hash with questions and all posibles answers
          @data[html_args[:id].to_sym] = {:question_text => question.question_text.downcase, :answers => {}, :points => question.points}
                  
          qtext.each_line do |p|
            @h.p do |par|
              par << p # preserves HTML markup
              if (question.class == FillIn)
                @h.input(:type => 'text', :id => "qfi#{index + 1}", :class => 'fillin') do
                end 
                @h.div(:id => "qfi#{index + 1}r") do
                end
              end
              @h.br
              @h.br
            end
          end
      end
      yield # render answers
    end
    self
  end

  def quiz_header
    @h.div(:id => 'student-name') do
      @h.p 'Name:'
      @h.p 'Student ID:'
    end
    if @quiz.options[:instructions]
      @h.div :id => 'instructions' do
        @quiz.options[:instructions].each_line { |p| @h.p p }
      end
    end
    self
  end

  def render_random_seed
    @h.comment! "Seed: #{@quiz.seed}"
  end
end
