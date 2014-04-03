quiz %q{REPASO. 2ª PARTE. <br />
ANÁLISIS SINTÁCTICO} do

  #head 'esto sale ALPRINCIPIO'
  
  fill_in do 
    text %q{
Dado un conjunto $A$, se define $A^*$ el cierre de Kleene de $A$ como:
\( A^* = \cup_{n=1}^{\infty} A^n \)
Se admite que $A^0 = \{ \epsilon \}$, donde $\epsilon$ denota la
--------------- --- esto es
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
    text %q{
Recuerde el <b>analizador sintáctico descendente predictivo recursivo</b> 
para la <a id="grammar">gramática</a>:<br/>
<ul>
  <li> $\Sigma = \{ ; =, ID, P, ADDOP, MULOP, COMPARISON, (, ), NUM \}$, 
  <li> $V = \{ statements, statement, condition, expression, term, factor \}$
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

  fill_in do
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
      git push ------ -----------
      </pre>
    } 
    answer ["create", "chuchu", "heroku", "chuchu", "chuchu", "herokuapp"]+
           ['push', 'heroku']+
           ['heroku', 'tutu:master']
  end

  #foot "esto va al final"
  
end

