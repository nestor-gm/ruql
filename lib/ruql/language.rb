class Language
  
  def initialize(source)
    if (source.class == Symbol)
      @source = File.read(File.expand_path(source.to_s))
    else
      @source = source
    end
  end 
 
end 