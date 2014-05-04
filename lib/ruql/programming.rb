class Programming < Question
 
  attr_accessor :case_sensitive, :language, :height, :width
  
  def initialize(text='', opts={})
    super
    self.question_text = text
    self.case_sensitive = !!opts[:case_sensitive]
    self.language = opts[:language] || 'javascript'
    self.height = opts[:height] || 800
    self.width = opts[:width] || 150
  end
 
  def multiple ; false ; end
  
end