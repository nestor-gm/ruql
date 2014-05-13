id_textareas = {};

$("textarea").each(function() { 
  id_textareas[this.id] = {};
  id_textareas[this.id]['id'] = this.id;
  numQuestion = parseInt(this.id.split('-')[0].slice(2)) - 1;
  id_textareas[this.id]['height'] = data['question-' + numQuestion.toString()]['height'];
  id_textareas[this.id]['width'] = data['question-' + numQuestion.toString()]['width'];
});

$.each(id_textareas, function(k,v) {
  id_textareas[k]['editor'] = CodeMirror.fromTextArea(document.getElementById(k), {
    lineNumbers: true,
    viewportMargin: Infinity
  });
  id_textareas[k]['editor'].setSize(id_textareas[k]['width'], id_textareas[k]['height']);
  id_textareas[k]['editor'].setValue('');
});