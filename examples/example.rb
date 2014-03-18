quiz 'Example quiz' do
 
  fill_in :points => 2 do
    text 'The capital of California is ---'
    answer /^\s*[sS]acramento\s*$/
  end

  fill_in do
    text 'The --- brown fox jumped over the lazy ---'
    answer [/fox/, /dog/], :explanation => 'This sentence contains all of the letters of the English Alphabet'
  end
  
  fill_in do
    text 'The three stooges are ---, ---, and ---.'
    answer %w(larry moe curly), :order => true 
  end
  
  fill_in do
    text 'The visionary founder of Apple is ---'
    answer /^ste(ve|phen)\s+jobs$/
    distractor /^steve\s+wozniak/, :explanation => 'Almost, but not quite.'
  end
  
  fill_in :points => 2 do
    text %q{
      When $a \ne 0$, there are two solutions to \(ax^2 + bx + c = 0\)
      and they are
      $$x = {-b \pm \sqrt{b^2-4ac} \over 2a}.$$
      <br/>
      The capital of <i>California</i> is ---
    }
    answer /^\s*[sS]acramento\s*$/
  end
  
  choice_answer :randomize => true do
    text  "What is the largest US state?"
    explanation "Not big enough." # for distractors without their own explanation
    answer 'Alaska'
    distractor 'Hawaii'
    distractor 'Texas', :explanation => "That's pretty big, but think colder."
  end
  
  select_multiple do
    text "Which are American political parties?"
    answer "Democrats"
    answer "Republicans"
    answer "Greens", :explanation => "Yes, they're a party!"
    distractor "Tories", :explanation => "They're British"
    distractor "Social Democrats"
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
  
end