require 'htmlentities'

class Question
  attr_accessor :question_text, :answers, :randomize, :points, :name, :question_tags, :question_comment, :default_explanation, :keys
  
  def initialize(*args)
    options = if args[-1].kind_of?(Hash) then args[-1] else {} end
    @answers = options[:answers] || []
    @points = [options[:points].to_i, 1].max
    @raw = options[:raw]
    @name = options[:name]
    @question_tags = []
    @question_comment = ''
    @default_explanation = ''
    @keys = []
  end

  def raw? ; !!@raw ; end
  
  def text(s) ; @question_text = s ; end
  
  def textanswer(text, opts={})
    @question_text = text.split(/{\w+}/).join()
    answers = []
    substring = text.split(' ')
    substring.each { |s| answers << s if (s =~ /----+{\w+}/)}
    answers.each { |a| @answers << Answer.new(a[/\w+/], correct=true, opts[:explanation]) }
  end
  
  def texthash(text, opts={})
    @question_text = text.split(/{\w+}/).join()
    substring = text.split(' ')
    substring.each { |s| @keys << s[/\w+/].to_sym if (s =~ /----+{\w+}/)}
  end
  
  def escape(text)
    coder = HTMLEntities.new
    coder.encode(text)
  end
  
  def answerhash(hash, opts={})
    @keys.each { |k| @answers << Answer.new(hash[k], correct=true, opts[:explanation])}
  end
  
  def explanation(text)
    @default_explanation = text
  end

  def answer(text, opts={})
    @answers << Answer.new(text, correct=true, opts[:explanation])
  end

  def distractor(text, opts={})
    @answers << Answer.new(text, correct=false, opts[:explanation] || @default_explanation)
  end

  # these are ignored but legal for now:
  def tags(*args) # string or array of strings 
    if args.length > 1
      @question_tags += args.map(&:to_s)
    else
      @question_tags << args.first.to_s
    end
  end

  def comment(str = '')
    @question_comment = str.to_s
  end

  def correct_answer ;  @answers.detect(&:correct?)  ;  end

  def correct_answers ;  @answers.collect(&:correct?) ; end

end
