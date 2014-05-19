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
  
  def text(s, opts={})
    regexp = /{:?\w+}/ 
    if (s[/---+{:?\w+}/] == nil)
      @question_text = s
    else
      @question_text = s.split(regexp).join()
      answers = s.scan(regexp)
      answers.each do |a|
        ans = a[/:?\w+/]
        if (ans[0] == ':')
          @keys << ans.delete(':').to_sym
        else
          @answers << Answer.new(ans, correct=true, opts[:explanation])
        end
      end
    end
  end
  
  def escape(text)
    coder = HTMLEntities.new
    coder.encode(text)
  end
  
  def explanation(text)
    @default_explanation = text
  end

  def answer(text, opts={})
    if (text.class == Hash)
      @keys.each { |k| @answers << Answer.new(text[k], correct=true, opts[:explanation])}
    else
      @answers << Answer.new(text, correct=true, opts[:explanation])
    end
  end

  def distractor(text, opts={})
    @answers << Answer.new(text, correct=false, opts[:explanation] || @default_explanation)
  end
  
  def relation(hash)
    hash.each_pair do |pair|
      @answers << Answer.new(Hash[*pair], correct=true)
    end
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
