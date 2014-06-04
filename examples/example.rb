quiz 'Example quiz' do

  teachers 'casiano.rodriguez.leon@gmail.com'
  
  students :'examples/students.txt'
  #students :'jjlabradorglez@gmail.com' => {:surname => 'Labrador González', :name => 'Juan José'}, :'tutu@gmail.com' => {:surname => 'Chuchu', :name => 'Tutu'}
  
  schedule :date_start => '27-05-2014', :date_finish => '28-05-2014', :time_start => '09:00', :time_finish => '11:00'
  
  heroku :domain => 'My Quiz'
  
  google_drive :spreadsheet_id => '1uUO8nlQ-WrHvqUNPMOK0sx17-hOG4JhkgjeFVb8SDKE'
  
  #head :'examples/header.html'
  
  tag = '<a href="www.google.es"></a> '
  fill_in do
    text "<i>Example of escaped HTML and three hyphens not evaluated:</i><br> #{escape(tag)}" + "<b>is</b> a \\-\\-\\- ---- " + '\-\-\-'
    answer /^link$/
  end
 
  fill_in :points => 2 do
    text 'The visionary founder of Apple is --------'
    comment 'Question too easy'
    answer /^ste(ve|phen)\s+jobs #comment $/imx
    distractor /^steve\s+wozniak/i, :explanation => 'Almost, but not quite.'
  end
  
  fill_in do
    text 'The ---- brown fox jumped over the lazy ----'
    answer [/fox/, /dog/], :explanation => 'This sentence contains all of the letters of the English Alphabet'
  end
  
  drag_drop_fill_in do
    text 'The ---- brown fox jumped over the lazy ----'
    answer ['fox', 'dog'], :explanation => 'This sentence contains all of the letters of the English Alphabet'
  end
  
  fill_in do
    text 'The three stooges are -----, ----, and -----.'
    answer %w(larry moe curly)
  end
  
  fill_in do
    text 'The three stooges are -----{larry}, ----{moe}, and -----{curly}.', :order => false
  end
  
  fill_in do
    text "The capital of Tenerife is -----{:santa} Cruz de --------{:tenerife}"
    answer :santa => /Santa/i, :tenerife => /Tenerife/i
  end
  
  fill_in do
    text %q{
      Diga dos números x = ---- e  y = ---- que multiplicados den 100
    }
    answer JS.new(%q{result = function(x,y) { return (x * y === 100); }})
  end

  programming :language => :javascript, :height => 150, :width => 800  do
    text %q{Write a JavaScript function named `suma` with two arguments that return the sum of them}
    answer JS.new(:'examples/test_suma.js')
  end
  
  fill_in do
    text %q{
      Calculate the determinant of this matrix:
      $$\mathbf{A} = \begin{vmatrix} 
      1 & 3 \\\\ 
      2 & 4 
      \end{vmatrix}$$
      <br/>
      ----
    }
    answer -1
  end
  
  fill_in do
    text %q{
      Solve: 
      $$\binom{n}{k} = \frac{n!}{k!(n-k)!}$$
      when n = 5 and k = 2:
      ----
    }
    explanation "Not exactly"
    answer 10
    distractor 9
  end
  
  fill_in do
    text %q{
      When x = 2, the solution of $\sqrt{3x+3}+(1+x)^2$ is:
      ----
    }
    answer 12
    distractor 11, :explanation => "Try again!"
  end

  choice_answer :randomize => true do
    text  "What is the largest US state?"
    explanation "Not big enough." # for distractors without their own explanation
    answer 'Alaska'
    distractor 'Hawaii'
    distractor 'Texas', :explanation => "That's pretty big, but think colder."
  end
 
  drag_drop_choice_answer do
    text  "Relate these concepts"
    relation :Facebook => 'Mark Zuckerberg', :Twitter => 'Jack Dorsey'
  end
  
  select_multiple do
    text "Which are American political parties?"
    answer "Democrats"
    answer "Republicans"
    answer "Greens", :explanation => "Yes, they're a party!"
    distractor "Tories", :explanation => "They're British"
    distractor "Social Democrats"
  end
  
  drag_drop_select_multiple do
    text  "Relate these concepts"
    relation :Ruby => ['Sinatra', 'Rails'], :JavaScript => 'jQuery'
  end
  
  truefalse 'The earth is flat.', false, :explanation => 'No, just looks that way'
  
  choice_answer :raw => true do
    text %Q{What does the following code do:
    <pre>
    puts "Hello world!"
    </pre>
    }
    distractor 'Throws an exception', :explanation => "Don't be an idiot."
    answer 'Prints a friendly message'
  end
  
  #foot :'examples/footer.html'

end
