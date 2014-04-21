class DragDrop < FillIn
  
  attr_accessor :order
  attr_accessor :case_sensitive
  
  def initialize(text='', opts={})
    super
    self.question_text = text
    self.case_sensitive = !!opts[:case_sensitive]
    self.order = true
  end
  
  def multiple ; false ; end
  
end