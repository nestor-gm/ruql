class SinatraRenderer < HtmlFormRenderer
  
  attr_reader :data
  
  def initialize(quiz,options={})
    super
  end
  
  def render_questions
    render_random_seed
    @h.form(:method => 'post', :action => '/quiz', :id => 'form') do
      content_form
    end
  end
  
  def insert_buttons_each_question(index, flag=false)
    @h.br do
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
    insert_in_template(code, tags, 'script', template)
  end
  
end
