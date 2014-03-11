quiz 'Example quiz' do
 
  fill_in :points => 2 do
    text 'The capital of California is ---'
    answer '/^\s*[sS]acramento\s*$/'
  end

  fill_in do
    text 'The --- brown fox jumped over the lazy ---'
    answer ['/fox/', '/dog/'], :explanation => 'This sentence contains all of the letters of the English Alphabet'
  end
  
  fill_in :order => true do
    text 'The three stooges are ---, ---, and ---.'
    answer %w(larry moe curly)
  end
  
  choice_answer :randomize => true do
    text  "What is the largest US state?"
    answer 'Alaska'
    distractor 'Hawaii'
    distractor 'Texas', :explanation => "That's pretty big, but think colder."
    explanation "Not big enough." # for distractors without their own explanation
  end
  
  select_multiple do
    text "Which are American political parties?"
    answer "Democrats"
    answer "Republicans"
    answer "Greens", :explanation => "Yes, they're a party!"
    distractor "Tories", :explanation => "They're British"
    distractor "Social Democrats"
  end
  
  select_multiple do
    text "Which are American political parties?"
    answer "Democrats"
    answer "Republicans"
    answer "Greens", :explanation => "Yes, they're a party!"
    distractor "Tories", :explanation => "They're British"
    distractor "Social Democrats"
  end
  
  truefalse 'The week has 7 days.', true
  truefalse 'The earth is flat.', false, :explanation => 'No, just looks that way'
  
end