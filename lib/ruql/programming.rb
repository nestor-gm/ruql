class Programming < Question
 
  attr_accessor :case_sensitive, :language, :lines, :width
  
  def initialize(text='', opts={})
    super
    self.question_text = text
    self.case_sensitive = !!opts[:case_sensitive]
    self.language = opts[:language] || 'javascript'
    self.lines = opts[:lines] || 5
    self.width = opts[:width] || 80
  end
 
  def multiple ; false ; end
  
end