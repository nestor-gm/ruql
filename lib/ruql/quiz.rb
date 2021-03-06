class Quiz
  @@quizzes = []
  def self.quizzes ; @@quizzes ;  end
  @@default_options = 
    {
    :open_time => Time.now,
    :soft_close_time => Time.now + 24*60*60,
    :hard_close_time => Time.now + 24*60*60,
    :maximum_submissions => 1,
    :duration => 3600,
    :retry_delay => 600,
    :parameters =>  {
      :show_explanations => {
        :question => 'before_soft_close_time',
        :option => 'before_soft_close_time',
        :score => 'before_soft_close_time',
      }
    },
    :maximum_score => 1,
  }

  attr_reader :renderer
  attr_reader :questions
  attr_reader :options
  attr_reader :output, :output_erb
  attr_reader :data, :users, :admins, :path_config
  attr_reader :seed
  attr_reader :logger
  attr_accessor :title

  def initialize(title, options={})
    @output = ''
    @output_erb = ''
    @questions = options[:questions] || []
    @title = title
    @options = @@default_options.merge(options)
    @seed = srand
    @logger = Logger.new(STDERR)
    @logger.level = Logger.const_get (options.delete('l') ||
      options.delete('log') || 'warn').upcase
  end

  def self.get_renderer(renderer)
    Object.const_get(renderer.to_s + 'Renderer') rescue nil
  end      

  def render_with(renderer,options={})
    srand @seed
    @renderer = Quiz.get_renderer(renderer).send(:new,self,options)
    @renderer.render_quiz
    if (renderer == 'Sinatra')
      @output = @renderer.output
      @output_erb = @renderer.output_erb
      @data = @renderer.data
      nil
    else
      @output = @renderer.output
    end
  end
  
  def points ; questions.map(&:points).inject { |sum,points| sum + points } ; end

  def num_questions ; questions.length ; end

  def random_seed(num)
    @seed = num.to_i
  end
  
  def constructor(klass, args)
    if args.first.is_a?(Hash) # no question text
      klass.new('',*args)
    else
      text = args.shift
      klass.new(text, *args)
    end
  end
  
  # this should really be done using mixins.
  def choice_answer(*args, &block)
    q = constructor(MultipleChoice, args)
    q.instance_eval(&block)
    @questions << q
  end

  def select_multiple(*args, &block)
    q = constructor(SelectMultiple, args)
    q.instance_eval(&block)
    @questions << q
  end

  def truefalse(*args)
    q = TrueFalse.new(*args)
    @questions << q
  end

  def fill_in(*args, &block)
    q = constructor(FillIn, args)
    q.instance_eval(&block)
    @questions << q
  end
  
  def drag_drop_fill_in(*args, &block)
    q = constructor(DragDrop_FI, args)
    q.instance_eval(&block)
    @questions << q
  end
  
  def drag_drop_choice_answer(*args, &block)
    q = constructor(DragDrop_MC, args)
    q.instance_eval(&block)
    @questions << q
  end
  
  def drag_drop_select_multiple(*args, &block)
    q = constructor(DragDrop_SM, args)
    q.instance_eval(&block)
    @questions << q
  end
  
  def programming(*args, &block)
    q = constructor(Programming, args)
    q.instance_eval(&block)
    @questions << q
  end
  
  def head_foot(arg)
    if (arg.class == String)
      arg
    elsif (arg.class == Symbol)
      File.read(File.expand_path(arg.to_s))
    end
  end
  
  def head(arg)
    @head = head_foot(arg)
  end
  
  def get_header
    @head
  end
  
  def foot(arg)
    @foot = head_foot(arg)
  end
  
  def get_footer
    @foot
  end
  
  def teachers(arg)
    @admins = arg
  end
  
  def students(arg)
    @users = arg
  end
  
  def config(path)
    @path_config = path
  end
  
  def self.quiz(*args,&block)
    quiz = Quiz.new(*args)
    quiz.instance_eval(&block)
    @@quizzes << quiz
  end
end
