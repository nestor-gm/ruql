quiz %q{REPASO. 2ª PARTE. <br />
ANÁLISIS SINTÁCTICO} do

  #head 'esto sale ALPRINCIPIO'
  
  # insert "<h1>Análisis Descendente Recursivo Predictivo</h1>
  fill_in do 
    text %q{
Dado un conjunto $A$, se define $A^*$ el cierre de Kleene de $A$ como:
\( A^* = \cup_{n=1}^{\infty} A^n \)
Se admite que $A^0 = \{ \epsilon \}$, donde $\epsilon$ denota la
palabra ---- esto es
la palabra que tiene longitud cero, formada por cero símbolos del conjunto base $A$.}
    answer [/palabra/i, /vac[ií]a/i], :order => true
  end

  fill_in do
    text %q{
Una producción de la forma $A \rightarrow A \alpha$.
se dice que es --------- por la ---------
}
    answer [/recursiva/i, /izquierda/i]
  end

  fill_in do
    text %q{Encuentre una gramática equivalente a esta:
      <pre>
        A: A 'a' | 'b'
      </pre>
      pero que no sea recursiva por la izquierda:
      <pre>
        A: -----
        R: /* vacío */ | -----
      </pre>
    }
    answer [ /   'b'
                 \s*
                  R
             /x, /'a'\s*R/]

  end

  fill_in do
    text %q{
Recuerde el <b>analizador sintáctico descendente predictivo recursivo</b> 
para la <a id="grammar">gramática</a>:<br/>
<ul>
  <li> $\Sigma = \{ ; =, ID, P, ADDOP, MULOP, COMPARISON, (, ), NUM \}$
  <li> $V = \\{ statements, statement, condition, expression, term, factor \\}$
  <li> Productions:
  <ol>
    <li>
    statements  $ \rightarrow$ statement ';' statements  $\vert$ statement
    <li>
    statement  $ \rightarrow$ ID '=' expression  $\vert$ P expression
 $ \vert$ IF condition THEN statement·
    <li> condition $ \rightarrow$ expression COMPARISON expression
    <li>
    expression  $ \rightarrow$ term ADDOP expression  $\vert$ term
    <li>
    term  $ \rightarrow$ factor MULOP term  $\vert$ factor
    <li>
    factor  $ \rightarrow$ '(' expression ')' $\vert$ ID $ \vert$ NUM
  </ol>
  <li> Start symbol: $statements$
</ul>
Rellene las partes que faltan de código CoffeeScript del 
método que se encarga de reconocer el lenguaje generado
por <tt>expression</tt>:
<pre>
  expression = ->
    result = term()
    while --------- and -------------- is "ADDOP"
      type = ---------.-----
      match "ADDOP"
      right = ------
      result =
        type: ----
        left: result
        right: right
    result
</pre>
}

  answer ["lookahead", "lookahead.type", "lookahead", "value", "term()", "type"], :order => true
  #comment "recuerde que el token actual esta en 'lookahead'"
  end

  fill_in :points => 3 do
    text %q{
Rellene las partes que faltan de código CoffeeScript del 
método que se encarga de reconocer el lenguaje generado
por <tt>statement</tt> para la <a href="#grammar">gramática
definida anteriormente</a>:
<pre>
  statement = ->
    result = null
    if --------- and ---------.---- is "ID"
      left =
        type: "ID"
        value: ---------.-----

      match "ID"
      match "="
      right = ----------()
      result =
        type: "="
        left: left
        right: right
    else if lookahead and lookahead.type is "P"
      match "P"
      right = ------------
      result =
        type: "P"
        value: right
    else if lookahead and lookahead.type is "IF"
      match "IF"
      left = -----------
      match "THEN"
      right = -----------
      result =
        type: "IF"
        left: left
        right: right
    else # Error!
      throw "Syntax Error. Expected identifier but found " + 
        (if lookahead then lookahead.value else "end of input") + 
        " near '#{input.substr(lookahead.from)}'"
    result

</pre>
}
  answer [ "lookahead", "lookahead", 
           "type", "lookahead", "value", "expression",
           "expression()", "condition()", "statement()"]
  end

  fill_in do
    text <<-'CONDITION'
Rellene las partes que faltan del código CoffeeScript
que reconoce el sublenguaje generado por <i>condition</i>:
  <pre>
  condition = ->
    left = -----------
    type = ---------.-----
    match "COMPARISON"
    right = ----------()
    result =
      type: type
      left: left
      right: right
    result
  </pre>
CONDITION
   answer ['expression()', 'lookahead', 'value', 'expression']
  end

  fill_in do
    text %q{
Complete este fragmento de <tt>slim</tt> que establece el favicon de 
la página HTML:} + 
%q{
<pre>
    link rel="-------------" type="image/jpg" href="images/favicon.jpg"
</pre>}
  answer /(shortcut\s+)?icon/i
  end

  fill_in :points => 6 do
    text %q{
      Para que un repositorio con una aplicación escrita en Ruby-Sinatra
      pueda desplegarse en Heroku con nombre <tt>chuchu</tt> el primer comando   que debemos escribir es:
      <pre>
      heroku ------ ------
      </pre>
      Este comando crea un remoto git cuyo nombre es ------
      y cuya URL es 
      <pre>
        git@heroku.com:-------.git
      </pre>
      La URL de publicación/despliegue será:
      http://---------.---------.com/
      <br/>
      Una vez que todo esta listo, para publicar nuestra versión
      en la rama <tt>master</tt> en heroku debemos ejecutar el comando:
      <pre>
      git ---- ------ master
      <br/>
      </pre>
      Si la versión que queremos publicar en heroku no está en la rama
      <tt>master</tt> sino que está en la rama <tt>tutu</tt> deberemos 
      modificar el comando anterior:
      <pre>
      git push ------ ----:------
      </pre>
      Para ver los logs deberemos emitir el comando:
      <pre>
       heroku ----
      </pre>
    } 
    answer ["create", "chuchu", "heroku", "chuchu", "chuchu", "herokuapp"]+
           ['push', 'heroku']+
           ['heroku', 'tutu', 'master']+
           ['logs']
  end

  fill_in do 
    text %q{Con que subcomando del cliente <tt>heroku</tt> abro el navegador
    en la URL del proyecto?<br/>
    <pre>
    heroku ----
    </pre>}
    answer 'open'
  end
  #
  # insert "<h1>PEGs</h1>
  
  fill_in do
    text %q{
      Escriba la parte que falta para que 
      el programa PEGJS reconozca el lenguaje
      $\\{ a^n b^n c^n\ /\ n \ge{} 1\\}$
      <pre>
      S = -------- 'a'+ B !('a'/'b'/'c')
      A = 'a' A? 'b'
      B = 'b' B? 'c'
      </pre>
    }
    answer [/\&\s*\(\s*A\s*'c'\s*\)/]
  end
  #foot "esto va al final"
  
  choice_answer :randomize => true do
    text %q{
Dado el PEGjs<a id="pegif"></a>:
<pre>
S =   if C:C then S1:S else S2:S { return [ 'ifthenelse', C, S1, S2 ]; }
    / if C:C then S:S            { return [ 'ifthen', C, S]; }
    / O                          { return 'O'; }
_ = ' '*
C = _'c'_                        { return 'c'; }
O = _'o'_                        { return 'o'; }
else = _'else'_                 
if = _'if'_
then = _'then'_    
</pre>
Considere esta entrada:
<pre>
if c then if c then o else o
</pre>
<!-- ['ifthen', 'c', ['ifthenelse', 'c', 'o', 'o']] -->
¿Cuál de los dos árboles es construido para la misma?:
}
answer %q{<tt>['ifthen', 'c', ['ifthenelse', 'c', 'o', 'o']]</tt>}
distractor %q{<tt>['ifthenelse', 'c', ['ifthen', 'c', 'o'], 'o']]</tt>}
  end

  choice_answer :randomize=>true do
    text %q{Si en el <a href="#pegif">peg anterior</a> cambiamos el orden de las dos primeras reglas de <tt>S</tt>:
<pre>
  S =   if C:C then S:S            { return [ 'ifthen', C, S]; }
      / if C:C then S1:S else S2:S { return [ 'ifthenelse', C, S1, S2 ]; }
</pre>
Para la misma entrada:
<pre>
if c then if c then o else o
</pre>
<!-- ['ifthen', 'c', ['ifthenelse', 'c', 'o', 'o']] -->
¿Cuál de las respuestas es correcta?
    }
    answer %{<tt>Syntax Error</tt>. La frase no es aceptada por el peg}
    distractor %q{<tt>['ifthen', 'c', ['ifthenelse', 'c', 'o', 'o']]</tt>}
    distractor %q{<tt>['ifthenelse', 'c', ['ifthen', 'c', 'o'], 'o']]</tt>}
  end

  fill_in do
    text %q{
Rellene las partes que faltan de este código para que funcione:
<pre>
var PEG = require ("pegjs");
var grammar = "s = ('a' / 'b')+";
var parser = PEG.-----------(grammar);
var input = process.argv[---] || 'abba';
console.log(parser.parse(input))
</pre>
Cuando se ejecuta, este código produce:
<pre>
[~/srcPLgrado/pegjs/examples(master)]$ node abba.pegjs abb
[ 'a', 'b', 'b' ]
</pre>
    }
    answer %w{buildParser 2}
  end

  fill_in do
    text %q{
<a id="anbncn"></a>
Complete las partes que faltan para que el PEGjs reconozca este
clásico ejemplo de lenguaje que no es independiente del contexto
               $\\{ a^nb^nc^n / n \ge{} 1 \\}$
<pre>
S = ---(--- ---) 'a'+ B:--- !('c'/[---]) { return B; }
A = 'a' A:A? 'b' { if (A) { return A+1; } else return 1; }
B = 'b' B:B? 'c' { if (B) { return B+1; } else return 1; }
</pre>
    }
    answer ['&', 'A', "'c'", "B", "^c"]
  end

  fill_in do
    text %q{
rellene las partes que faltan del siguiente programa PEGjs que reconoce
los comentarios Pascal:
<pre>
P     =   prog:N+                          { return prog; }
N     =   chars:$(!Begin ANY)+             { return chars;}
        / C
C     = Begin chars:--- End                { return chars.join(''); }
T     =   C 
        / (!----- ---- char:ANY)           { return char;}
Begin = '(*'
End   = '*)'
ANY   =   'z'    /* any character */       { return 'z';  }
        / char:----                        { return char; }    
</pre>
    }
    answer ["T*", "Begin", "!End", "[^z]"], :order => true
  end

  fill_in :points => 4 do
    text %q{
Rellene las partes que faltan de esta clase que implementa 
persistencia para programas PL0 usando el ORM DataMapper:
<pre>
DataMapper.-----(:default,·
                 ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/database.db" )

class PL0Program
  include ----------::--------
··
  -------- :name, String, :key => true
  -------- :source, String, :length => 1..1024
end

  DataMapper.--------
  DataMapper.-------------
</pre>
}
    answer ['setup', 
            'DataMapper', 'Resource', 
            'property', 
            'property',
            'finalize',
            'auto_upgrade!'
    ]
  end

  fill_in do
    text %q{
Rellene las partes que faltan del siguiente fragmento de código
de la ruta <tt>/save</tt>
que guarda el programa solicitado:
<pre>
post '/save' do
  name = params[:fname]
  c  = PL0Program.-----(:name => name)
  if c
    c.source = params["input"]
    c.----
  else
    c = PL0Program.new
    c.name = params["fname"]
    c.source = params["input"]
    c.----
  end
  -------- '/'
end
</pre>
}
    answer [ 'first', 'save', 'save', 'redirect']
  end

  fill_in :points => 4 do
    text %q{
En la práctica del PEGjs tratabamos las expresiones aritméticas 
mediante estas dos reglas:
<pre>
exp    = t:term   r:(ADD term)*   { return tree(t,r); }
term   = f:factor r:(MUL factor)* { return tree(f,r); }
ADD      = _ op:[+-] _ { return op; }
MUL      = _ op:[*/] _ { return op; }
</pre>
Complete el código de <tt>tree</tt>:
<pre>
{
  var tree = function(f, r) {
    if (r.------ > 0) {
      var last = r.----();
      var result = {
        type:  -------,
        left: ----------,
        right: -------
      };
    }
    else {
      var result = f;
    }
    return result;
  }
}
</pre>
}
    answer ['length', 
            'pop', 
            /last\s*\[\s*0\s*\]/, /tree\s*\(\s*f\s*,\s*r\s*\)/,
            /last\s*\[\s*1\s*\]/
           ]
  end
end
