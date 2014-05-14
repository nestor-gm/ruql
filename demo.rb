quiz 'Demo' do

  fill_in do
    text "The capital of Tenerife is -----{:santa} Cruz de --------{:tenerife}"
    answer :santa => /Santa/i, :tenerife => /Tenerife/i
  end
  
  drag_drop_fill_in do
    text 'The ---- brown fox jumped over the lazy ----'
    answer ['fox', 'dog'], :explanation => 'This sentence contains all of the letters of the English Alphabet'
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
  
  programming :language => :javascript, :height => 150, :width => 800  do
    text %q{Write a JavaScript function named `suma` with two arguments that return the sum of them}
    answer JS.new(:'examples/test_suma.js')
  end

end
