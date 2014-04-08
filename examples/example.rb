require 'htmlentities'

coder = HTMLEntities.new

quiz 'Example quiz' do

  #head :'examples/header.html'
  
  tag = '<a href="www.google.es"></a> '
  fill_in do
    text '<i>Example of escaped HTML and three hyphens not evaluated:</i><br>' + "#{coder.encode(tag)}" + '<b>is</b> a --- ---- ---'
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
  
  fill_in do
    text %Q{The three stooges are -----, ----, and -----.
  <li> $\Sigma = \{ ; =, ID, P, ADDOP, MULOP, COMPARISON, (, ), NUM \}$
  <li> $V = \\{ statements, statement, condition, expression, term, factor \\}$
    }
    answer %w(larry moe curly), :order => true 
  end
  
  fill_in do
    textanswer 'The three stooges are -----{larry}, ----{moe}, and -----{curly}.'
  end
  
  fill_in do
    texthash "The capital of Tenerife is -----{santa} Cruz de --------{tenerife}"
    answerhash :santa => /Santa/i, :tenerife => /Tenerife/i
  end
  
  fill_in do
    text %q{
      Diga dos números x = ---- e  y = ---- que multiplicados den 100
    }
    answer "result = lambda { |x, y| x * y == 100 }"
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
  
  #foot :'examples/footer.html'
  
end
