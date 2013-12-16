Ruby-based Quiz Generator and DSL
=================================

This is a simple gem that takes a set of questions (a "quiz") written in
RuQL ("Ruby quiz language" or "Ruby question language" - a DSL embedded
in Ruby), and produces one of several possible output formats.

Some types of questions or question elements that can be expressed in
RuQL cannot be expressed by some LMSs, and some LMS-specific question
features cannot be expressed in RuQL.

Installation
------------

`gem install ruql` to install this from RubyGems.  It works with Ruby
1.9.2 and 1.9.3; haven't tested it on other versions but should be fine.

License
-------

RuQL is licensed under Creative Commons BY-SA license v3.0 or any later
version.  You can use it for any purpose, including commercial, and you
can create derivative works, but the following attribution must be
preserved:  "Copyright 2012 Strawberry Canyon LLC".  And you  must be
willing to share your improvements back to this repo.

Creating Quiz Questions in RuQL
===============================

RuQL supports a few different types of short-answer questions and can
output them in a variety of formats compatible with different Learning
Management Systems or in printable form.

RuQL is a DSL embedded in Ruby, so you can include expressions in
questions, for example, to generate simple variants of a question along
with its solution.

Short-answer fill-in-the-blanks questions
-----------------------------------------

Put three or more hyphens in a row where you want the "blanks" to be,
and provide a string or regexp to check the answer; all regexps are 
case-INSENSITIVE unless :case_sensitive => true is passed.  

```ruby
fill_in :points => 2 do
  text 'The capital of California is ---.'
  answer 'sacramento'
end
```

Optional distractors can capture common incorrect answers.  As with all
question types, an optional `:explanation` can accompany a correct
answer or a distractor; its usage varies with the LMS, but a typical use
is to display a hint if the wrong answer is given, or to display
explanatory text accompanying the correct answer.

```ruby
fill_in do
  text 'The visionary founder of Apple is ---'
  answer /^ste(ve|phen)\s+jobs$/
  distractor /^steve\s+wozniak/, :explanation => 'Almost, but not quite.'
end
```

You can have multiple blanks per question and pass an array of regexps
or strings to check them.  Passing `:order => false` means that the
order in which blanks are filled doesn't matter.  The number of elements
in the array must exactly match the number of blanks.

```ruby
fill_in do
  text 'The --- brown fox jumped over the lazy ---'
  answer [/fox/, /dog/], :explanation => 'This sentence contains all of the letters of the English Alphabet'
end

fill_in do
  text 'The three stooges are ---, ---, and ---.'
  answer %w(larry moe curly), :order => false
end
```

Multiple-choice questions with a single correct answer
------------------------------------------------------

You can provide a generic `explanation` clause, and/or override it with
specific explanations to accompany right or wrong answers.
If `:randomize => true` is given as an optional argument to the
question, the order of choices may be randomized, depending on the LMS's
capabilities.  Otherwise, choices are presented in the order in which
they appear in the RuQL markup.

```ruby
choice_answer :randomize => true do
  text  "What is the largest US state?"
  explanation "Not big enough." # for distractors without their own explanation
  answer 'Alaska'
  distractor 'Hawaii'
  distractor 'Texas', :explanation => "That's pretty big, but think colder."
end
```

Specifying `:raw => true` allows HTML markup in the question to be
passed through unescaped.  DEPRECATION WARNING: this was originally
included for allowing code blocks in questions.  It is probably going
away so don't rely on it.

```ruby
  choice_answer :raw => true do
    text %Q{What does the following code do:
<pre>
  puts "Hello world!"
</pre>
}
    distractor 'Throws an exception', :explanation => "Don't be an idiot."
    answer 'Prints a friendly message'
  end
```

Multiple-choice "select all that apply" questions
-------------------------------------------------

These use the same syntax as single-choice quetsions, but multiple
`answer` clauses are allowed:

```ruby
select_multiple do
  text "Which are American political parties?"
  answer "Democrats"
  answer "Republicans"
  answer "Greens", :explanation => "Yes, they're a party!"
  distractor "Tories", :explanation => "They're British"
  distractor "Social Democrats"
end
```

True or false questions
-----------------------

Internally, true/false questions are treated as a special case of
multiple-choice questions with a single correct answer, but there's a
shortcut syntax for them.

```ruby
truefalse 'The week has 7 days.', true
truefalse 'The earth is flat.', false, :explanation => 'No, just looks that way'
```

Preparing a quiz
----------------

A quiz is a collection of questions in the `do` block of a `quiz`,
which has a mandatory name argument:

    quiz 'Example quiz' do   
      # (questions here)
    end

You create a quiz by putting the quiz in its own file and
copying-and-pasting the questions you want into it.  (Yes, that's ugly.
Soon, questions will have unique IDs and you'll be able to create a quiz
by reference.)

Additional arguments and options
--------------------------------

The following arguments and options have different behavior (or no
effect on behavior) depending on what format questions are emitted in:

1. All question types accept a `:name => 'something'` argument, which some
output generators use to create a displayable name for the question or
to identify it within a group of questions.

2. The optional `tag` clause is followed by a string or array of strings,
and associates the given tag(s) with the question, in anticipation of
future tools that can use this information.

3. The optional `comment` clause is followed by a string and allows a
free-text comment to be added to a question.


Using questions with Open EdX
=============================

To quickly add an inline question (multiple choice, text or numeric
input, or option dropdown) to a course unit in EdX Studio:

1. Create the question in RuQL with an attribute `:name => "some-name"`
and put it in some file `questions.rb` 
2. Run `ruql questions.rb edxml -n some-name`
3. Copy the resulting XML to the Clipboard.  In Studio, select "Advanced
Editor" view for the question, which shows the raw XML of the question.
Replace that raw XML with the output from `ruql`.
4. Visually check that the question looks right in Studio, since some
markup that is legal in RuQL doesn't format correctly in Studio.


Creating a Printable Version of a Quiz
======================================

3. Run the generator as follows (it's unwieldy now but it'll get
better):

To generate an HTML version suitable for viewing in a browser:
(./quiz with no arguments shows brief help)

./quiz questionfile.rb html5 --template=./html_template/template.html.erb > questionfile.html

If you also specify --solutions on command line, you can generate an
HTML5 version that includes identification of the correct answer.
(NOTE: the HTML5 tags clearly identify the correct answer--this format
is meant for printing, not for online use, since a simple "view page
source" would show the correct answers!)

You can replace the existing html.erb template with your own; take a
look at it to see how it works.

Creating a Coursera-Compatible Version of a Quiz
================================================

To generate a version that can be ingested by Coursera's online
quiz-taking machinery:

./quiz questionfile.rb xml > questionfile.xml

Please add to this documentation using the Wiki or by adding inline RDoc
comments to the code!

