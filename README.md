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

The HTML Form renderer allows Fixnum answer too and the number of hyphens
indicates the size of the answer input. It's possible to escape three or more 
hyphens using the slash ('\') for each hyphen if you use single quotes or
double slashes ("\\") for double quotes. 

To escape any HTML tag use the escape method:

```ruby
  escape('<a href="www.google.es"></a>')
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
order in which blanks are filled doesn't matter.  By default, the order is
set to true. The number of elements in the array must exactly match the number of blanks.

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

Another notation is allowed to fill_in questions for HTML Form renderer when all answers are strings:

```ruby
fill_in do
  text 'The three stooges are -----{larry}, ----{moe}, and -----{curly}.', :order => false
end
```

The HTML Form renderer allows a JavaScript object in a fill_in answer. The JavaScript code is
a parameter of the constructor. It must be written like a string and it must return true or false.

```ruby
fill_in do
  text %q{
    Write two numbers x = ---- e  y = ---- which multiplication's result would be equal to 100
  }
  answer JS.new(%q{result = function(x,y) { return (x * y === 100); }})
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

These use the same syntax as single-choice questions, but multiple
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

Drag-and-Drop questions
-----------------------

This kind of questions is only supported in the HTML Form renderer. There are three types:

### Drag-and-Drop fill_in question

The syntax is quite similar to the fill_in questions. The only restriction is that all the answers must be
strings or numbers:

```ruby
drag_drop_fill_in do
  text 'The ---- brown fox jumped over the lazy ----'
  answer ['fox', 'dog'], :explanation => 'This sentence contains all of the letters of the English Alphabet'
end
```

### Drag-and-Drop multiple-choice question

```ruby
drag_drop_choice_answer do
  text  "Relate these concepts"
  relation :Facebook => 'Mark Zuckerberg', :Twitter => 'Jack Dorsey'
end
```

### Drag-and-Drop select-multiple question

```ruby
drag_drop_select_multiple do
  text  "Relate these concepts"
  relation :Ruby => ['Sinatra', 'Rails'], :JavaScript => 'jQuery'
end
```

Programming questions
---------------------

This kind of question generate a textarea where the code can be typed. It's possible to customize
the height and the width of the textarea using `:height` and `:width`. 

As the validation take place in the client's browser, JavaScript code is the only language supported.

```ruby
programming :language => :javascript, :height => 150, :width => 800  do
  text %q{Write a JavaScript function named 'suma' with two arguments that return the sum of them}
  answer JS.new(:'examples/test_suma.js')
end
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


Generating a quiz from a RuQL file
==================================

Using questions with Open EdX
-----------------------------

To quickly add an inline question (multiple choice, text or numeric
input, or option dropdown) to a course unit in EdX Studio:

1. Create the question in RuQL with an attribute `:name => "some-name"`
and put it in some file `questions.rb` 
2. Run `ruql questions.rb EdXml -n some-name`
3. Copy the resulting XML to the Clipboard.  In Studio, select "Advanced
Editor" view for the question, which shows the raw XML of the question.
Replace that raw XML with the output from `ruql`.
4. Visually check that the question looks right in Studio, since some
markup that is legal in RuQL doesn't format correctly in Studio.


Creating an HTML 5 or Printable Version of a Quiz
-------------------------------------------------

Run `ruql questionfile.rb Html5 --template=template.html.erb`

The optional template should be an `.html.erb` template in which `yield`
is rendered where the questions should go.  If you omit the `template`
argument, you'll get the `html5.html.erb` file template that comes in
the `templates` directory of the gem.

If you also specify `--solutions` on the command line, you can generate
an HTML5 version that includes identification of the correct answer.
NOTE that if you do this, the HTML5 tags will clearly identify the correct
answer--this format is meant for printing, not for online use, since a
simple "view page source" would show the correct answers!

Creating an HTML Form Version of a Quiz
-------------------------------------------------

Run `ruql questionfile.rb HtmlForm --template=template.html.erb > output.html`

The optional template should be an `.html.erb` template in which `yield` 
is rendered where the questions should go.  If you omit the `template`
argument, you'll get the `htmlform.html.erb` file template that comes in
the `templates` directory of the gem. This template uses some elements of Twitter Bootstrap.

NOTE: the -c, -j and -h options can be used with the default template too.

It's possible to add a custom header/footer to the template. It can be a symbol with the path
of the file or a string with the HTML code. This header/footer will replace
the default header/footer:

```ruby
  head :'examples/header.html'
  foot '<footer>Custom footer</footer>'
```

Besides, this renderer has the following features:
+ JavaScript validation of answers.
+ Local Storage for answers.
+ Context menu on right-click event to show answers (strings, regexps or numbers) of fill_in questions.
+ English and Spanish languages supported.
+ The options of Ruby Regexps support -s option. (Using XRegExp)  - http://xregexp.com/
+ Used the MathJax library to use LaTeX expressions - http://www.mathjax.org/. 
Use a slash for the braces if you use a single quote ('\\{\\}') or two slashes for double quotes ("\\\\{\\\\}").

In the [examples' directory](http://github.com/jjlabrador/ruql/blob/develop/examples/example.rb) there's an example quiz that contains all the features of this renderer.
Use `rake example` to generate it (executing the source code).

To a local installation of the gem, use `rake install`.

Creating an AutoQCM quiz
------------------------

The [AutoQCM](home.gna.org/auto-qcm/) tool uses LaTeX to create a
multiple-choice quiz with answer bubbles, and includes software to
automatically score scanned multiple-choice answer sheets it creates.

You can generate (mostly) AutoQCM-compatible LaTeX input sources from a
set of RuQL questions:

`ruql questionfile.rb AutoQCM  --template=my_template.tex.erb`

The template file will be run through `erb` and should render `yield`
where the questions should be.  A template file is *mandatory* for
AutoQCM.  If you omit the template argument, you'll get the
`autoqcm.tex.erb` template in the gem's `templates` directory.

The command-line option `--penalty=0.8` takes a number that indicates
what fraction of the question's total points should be deducted as a
penalty for wrong answer.  For example, a question worth 4 points with a
penalty of 0.25 means the student receives -1 point for the question, as
opposed to zero points for leaving it blank.  Default if omitted is
zero.  This information is just embedded in the file that will be passed
to AutoQCM.

There are additional renderers not described here.  The renderer
misleadingly called 'XmlRenderer' once upon a time generated
Coursera-compatible markup, but that was long ago.  The JSON renderer
outputs questions in the [MOOCdb](http://moocrp.herokuapp.com) format.
