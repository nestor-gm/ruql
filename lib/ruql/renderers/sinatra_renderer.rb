class SinatraRenderer < HtmlFormRenderer
  
  attr_reader :data
  
  def initialize(quiz,options={})
    super
  end
  
  def render_questions
    render_random_seed
    @h.form(:method => 'post', :action => '/', :id => 'form') do
      content_form
    end
  end
  
  def insert_buttons_each_question(index, flag=false)
    insert_button("show-answer-q-#{index}", translate(:show, 'buttons'), 'btn btn-success btn-sm') if flag
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
    }
    tags = %Q{
      <script type="text/javascript">
        #{code}
      </script>
    }
    insert_in_template(code, tags, 'script', template)
  end
  
end
